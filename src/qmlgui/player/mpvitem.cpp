/*
 * Bittorrent Client using Qt and libtorrent.
 * Copyright (C) 2026  Flux contributors
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 *
 * In addition, as a special exception, the copyright holders give permission to
 * link this program with the OpenSSL project's "OpenSSL" library (or with
 * modified versions of it that use the same license as the "OpenSSL" library),
 * and distribute the linked executables. You must obey the GNU General Public
 * License in all respects for all of the code used other than "OpenSSL".  If you
 * modify file(s), you may extend this exception to your version of the file(s),
 * but you are not obligated to do so. If you do not wish to do so, delete this
 * exception statement from your version.
 */

#include "mpvitem.h"

#include <algorithm>
#include <clocale>
#include <cstdlib>

#include <QDebug>
#include <QDir>
#include <QGuiApplication>
#include <QUrl>
#include <QVariantMap>

#include "base/global.h"

#ifdef FLUX_HAS_MPV
#include <QOpenGLContext>
#include <QOpenGLFramebufferObject>
#include <QPointer>
#include <QQuickOpenGLUtils>

#include <mpv/client.h>
#include <mpv/render_gl.h>

namespace
{
    QVariant nodeToVariant(const mpv_node *node)
    {
        switch (node->format)
        {
        case MPV_FORMAT_STRING:
            return QString::fromUtf8(node->u.string);
        case MPV_FORMAT_FLAG:
            return bool(node->u.flag);
        case MPV_FORMAT_INT64:
            return qlonglong(node->u.int64);
        case MPV_FORMAT_DOUBLE:
            return node->u.double_;
        case MPV_FORMAT_NODE_ARRAY:
        {
            QVariantList list;
            for (int i = 0; i < node->u.list->num; ++i)
                list.append(nodeToVariant(&node->u.list->values[i]));
            return list;
        }
        case MPV_FORMAT_NODE_MAP:
        {
            QVariantMap map;
            for (int i = 0; i < node->u.list->num; ++i)
                map.insert(QString::fromUtf8(node->u.list->keys[i]), nodeToVariant(&node->u.list->values[i]));
            return map;
        }
        default:
            return {};
        }
    }

    void *getProcAddress(void *, const char *name)
    {
        QOpenGLContext *ctx = QOpenGLContext::currentContext();
        return ctx ? reinterpret_cast<void *>(ctx->getProcAddress(QByteArray(name))) : nullptr;
    }

    class MpvRenderer final : public QQuickFramebufferObject::Renderer
    {
    public:
        MpvRenderer(MpvItem *item, std::shared_ptr<mpv_handle> mpv)
            : m_item {item}
            , m_mpv {std::move(mpv)}
        {
            // createRenderer() runs on the render thread with the scene-graph GL context current
            mpv_opengl_init_params glInit {&getProcAddress, nullptr};
            int advanced = 0;
            mpv_render_param params[] {
                {MPV_RENDER_PARAM_API_TYPE, const_cast<char *>(MPV_RENDER_API_TYPE_OPENGL)},
                {MPV_RENDER_PARAM_OPENGL_INIT_PARAMS, &glInit},
                {MPV_RENDER_PARAM_ADVANCED_CONTROL, &advanced},
                {MPV_RENDER_PARAM_INVALID, nullptr}};
            const int err = mpv_render_context_create(&m_ctx, m_mpv.get(), params);
            if (err < 0)
            {
                qWarning("mpv_render_context_create failed: %s", mpv_error_string(err));
                m_ctx = nullptr;
                return;
            }
            // mpv calls back from its own threads: hop to the GUI thread, where the item may be gone
            mpv_render_context_set_update_callback(m_ctx, &MpvRenderer::onUpdate, this);
            QMetaObject::invokeMethod(qApp, [item = m_item] { if (item) emit item->rendererReady(); }, Qt::QueuedConnection);
        }

        ~MpvRenderer() override
        {
            // with the GL context current (scene-graph teardown), before mpv itself is destroyed
            if (m_ctx)
                mpv_render_context_free(m_ctx);
        }

        QOpenGLFramebufferObject *createFramebufferObject(const QSize &size) override
        {
            QOpenGLFramebufferObjectFormat format;
            format.setAttachment(QOpenGLFramebufferObject::NoAttachment);
            return new QOpenGLFramebufferObject(size, format);
        }

        void render() override
        {
            if (!m_ctx)
                return;
            QOpenGLFramebufferObject *fbo = framebufferObject();
            mpv_opengl_fbo mpfbo {static_cast<int>(fbo->handle()), fbo->width(), fbo->height(), 0};
            int flipY = 0;
            // mpv's default (1) sleeps in render() until the frame's display time, stalling Qt's render
            // thread and every animation over the video; 0 renders at once
            int block = 0;
            mpv_render_param params[] {
                {MPV_RENDER_PARAM_OPENGL_FBO, &mpfbo},
                {MPV_RENDER_PARAM_FLIP_Y, &flipY},
                {MPV_RENDER_PARAM_BLOCK_FOR_TARGET_TIME, &block},
                {MPV_RENDER_PARAM_INVALID, nullptr}};
            mpv_render_context_render(m_ctx, params);
            // mpv changes GL state behind Qt's back
            QQuickOpenGLUtils::resetOpenGLState();
        }

    private:
        static void onUpdate(void *ctx)
        {
            auto *self = static_cast<MpvRenderer *>(ctx);
            QMetaObject::invokeMethod(qApp, [item = self->m_item] { if (item) item->update(); }, Qt::QueuedConnection);
        }

        QPointer<MpvItem> m_item;
        std::shared_ptr<mpv_handle> m_mpv;
        mpv_render_context *m_ctx = nullptr;
    };

    QVariantList tracksOfType(const QVariantList &trackList, const QString &type)
    {
        QVariantList tracks;
        for (const QVariant &v : trackList)
        {
            const QVariantMap t = v.toMap();
            if (t.value(u"type"_s) != type)
                continue;
            tracks.append(QVariantMap {
                {u"id"_s, t.value(u"id"_s).toInt()},
                {u"title"_s, t.value(u"title"_s).toString()},
                {u"lang"_s, t.value(u"lang"_s).toString()},
                {u"codec"_s, t.value(u"codec"_s).toString()},
                {u"external"_s, t.value(u"external"_s).toBool()}
            });
        }
        return tracks;
    }

    int trackId(const QVariant &value)
    {
        // "aid"/"sid" are a track id, or the flag/string "no"
        bool ok = false;
        const int id = value.toInt(&ok);
        return ok ? id : 0;
    }
}
#endif

MpvItem::MpvItem(QQuickItem *parent)
    : MpvItemBase(parent)
{
#ifdef FLUX_HAS_MPV
    // mpv parses numbers with the C locale
    std::setlocale(LC_NUMERIC, "C");

    mpv_handle *raw = mpv_create();
    if (!raw)
    {
        setError(tr("The video player could not start."));
        return;
    }
    m_mpv = std::shared_ptr<mpv_handle>(raw, [](mpv_handle *h) { mpv_terminate_destroy(h); });

    mpv_set_option_string(raw, "vo", "libmpv");
    mpv_set_option_string(raw, "hwdec", "auto-safe");
    mpv_set_option_string(raw, "keep-open", "yes");
    mpv_set_option_string(raw, "terminal", "no");
    mpv_set_option_string(raw, "msg-level", "all=warn");
    mpv_set_option_string(raw, "input-default-bindings", "no");
    mpv_set_option_string(raw, "sub-auto", "fuzzy");
    mpv_set_option_string(raw, "slang", "ru,rus,en,eng");
    mpv_set_option_string(raw, "alang", "ru,rus,en,eng");
    // a stream still downloading: read ahead generously, wait instead of failing
    mpv_set_option_string(raw, "cache", "yes");
    mpv_set_option_string(raw, "demuxer-max-bytes", "256MiB");
    mpv_set_option_string(raw, "network-timeout", "120");
    mpv_request_log_messages(raw, "warn");

    if (const int err = mpv_initialize(raw); err < 0)
    {
        setError(QString::fromUtf8(mpv_error_string(err)));
        m_mpv.reset();
        return;
    }

    for (const char *name : {"pause", "time-pos", "duration", "demuxer-cache-time", "paused-for-cache", "seeking"
            , "volume", "mute", "track-list", "aid", "sid", "video-bitrate", "audio-bitrate", "file-size", "eof-reached"})
        mpv_observe_property(raw, 0, name, MPV_FORMAT_NODE);
    mpv_set_wakeup_callback(raw, [](void *ctx)
    {
        QMetaObject::invokeMethod(static_cast<MpvItem *>(ctx), &MpvItem::processEvents, Qt::QueuedConnection);
    }, this);

    connect(this, &MpvItem::rendererReady, this, &MpvItem::onRendererReady);
    // mpv's FBO is bottom-up like any GL default framebuffer
    setMirrorVertically(true);
#else
    setFlag(ItemHasContents, false);
#endif
}

MpvItem::~MpvItem()
{
#ifdef FLUX_HAS_MPV
    if (m_mpv)
        mpv_set_wakeup_callback(m_mpv.get(), nullptr, nullptr);
#endif
}

#ifdef FLUX_HAS_MPV
QQuickFramebufferObject::Renderer *MpvItem::createRenderer() const
{
    return new MpvRenderer(const_cast<MpvItem *>(this), m_mpv);
}
#endif

bool MpvItem::isAvailable()
{
#ifdef FLUX_HAS_MPV
    return true;
#else
    return false;
#endif
}

std::shared_ptr<mpv_handle> MpvItem::handle() const
{
    return m_mpv;
}

QString MpvItem::source() const { return m_source; }
double MpvItem::startPosition() const { return m_startPosition; }
bool MpvItem::isPaused() const { return m_paused; }
double MpvItem::position() const { return m_position; }
double MpvItem::duration() const { return m_duration; }
double MpvItem::cachedUntil() const { return m_cachedUntil; }
bool MpvItem::isBuffering() const { return m_buffering; }
bool MpvItem::isSeeking() const { return m_seeking; }
bool MpvItem::isLoaded() const { return m_loaded; }
int MpvItem::volume() const { return m_volume; }
bool MpvItem::isMuted() const { return m_muted; }
QVariantList MpvItem::audioTracks() const { return m_audioTracks; }
QVariantList MpvItem::subtitleTracks() const { return m_subtitleTracks; }
int MpvItem::audioTrack() const { return m_audioTrack; }
int MpvItem::subtitleTrack() const { return m_subtitleTrack; }
qint64 MpvItem::bitrate() const { return m_bitrate; }
QString MpvItem::hwdec() const { return m_hwdec; }
QString MpvItem::error() const { return m_error; }

void MpvItem::setSource(const QString &source)
{
    if (source == m_source)
        return;
    m_source = source;
    emit sourceChanged();
    loadSource();
}

void MpvItem::setStartPosition(const double seconds)
{
    if (qFuzzyCompare(seconds + 1, m_startPosition + 1))
        return;
    m_startPosition = seconds;
    emit startPositionChanged();
}

void MpvItem::setPaused(const bool paused)
{
    setMpvProperty(u"pause"_s, paused);
}

void MpvItem::setVolume(const int volume)
{
    setMpvProperty(u"volume"_s, std::clamp(volume, 0, 130));
}

void MpvItem::setMuted(const bool muted)
{
    setMpvProperty(u"mute"_s, muted);
}

void MpvItem::setAudioTrack(const int id)
{
    setMpvProperty(u"aid"_s, (id > 0) ? QVariant(QString::number(id)) : QVariant(u"no"_s));
}

void MpvItem::setSubtitleTrack(const int id)
{
    setMpvProperty(u"sid"_s, (id > 0) ? QVariant(QString::number(id)) : QVariant(u"no"_s));
}

void MpvItem::setHwdec(const QString &hwdec)
{
    if (hwdec == m_hwdec)
        return;
    m_hwdec = hwdec;
    setMpvProperty(u"hwdec"_s, hwdec);
    emit hwdecChanged();
}

void MpvItem::setError(const QString &error)
{
    if (error == m_error)
        return;
    m_error = error;
    emit errorChanged();
}

void MpvItem::onRendererReady()
{
    m_rendererReady = true;
    loadSource();
}

void MpvItem::loadSource()
{
#ifdef FLUX_HAS_MPV
    // a file loaded before the render context exists gets no video output: wait for the renderer
    if (!m_mpv || !m_rendererReady)
        return;
    if (m_loaded)
    {
        m_loaded = false;
        emit loadedChanged();
    }
    m_eof = false;
    setError({});
    if (m_source.isEmpty())
    {
        command({u"stop"_s});
        return;
    }
    const QUrl url {m_source};
    const QString target = url.isLocalFile() ? QDir::toNativeSeparators(url.toLocalFile()) : m_source;
    // "start" applies to the next loadfile; it is cleared again once the file is loaded
    setMpvProperty(u"start"_s, (m_startPosition > 0) ? QVariant(QString::number(m_startPosition, 'f', 3)) : QVariant(u"none"_s));
    command({u"loadfile"_s, target});
#endif
}

void MpvItem::togglePause()
{
    command({u"cycle"_s, u"pause"_s});
}

void MpvItem::seek(const double seconds)
{
    command({u"seek"_s, QString::number(std::max(0.0, seconds), 'f', 3), u"absolute"_s});
}

void MpvItem::seekRelative(const double seconds)
{
    command({u"seek"_s, QString::number(seconds, 'f', 3), u"relative"_s});
}

void MpvItem::stop()
{
    command({u"stop"_s});
}

void MpvItem::addSubtitle(const QString &path)
{
    command({u"sub-add"_s, QDir::toNativeSeparators(path), u"auto"_s});
}

QVariant MpvItem::mpvProperty(const QString &name) const
{
#ifdef FLUX_HAS_MPV
    if (!m_mpv)
        return {};
    mpv_node node;
    if (mpv_get_property(m_mpv.get(), name.toUtf8().constData(), MPV_FORMAT_NODE, &node) < 0)
        return {};
    const QVariant value = nodeToVariant(&node);
    mpv_free_node_contents(&node);
    return value;
#else
    Q_UNUSED(name);
    return {};
#endif
}

bool MpvItem::setMpvProperty(const QString &name, const QVariant &value)
{
#ifdef FLUX_HAS_MPV
    if (!m_mpv)
        return false;
    const QByteArray v = (value.typeId() == QMetaType::Bool)
        ? QByteArray(value.toBool() ? "yes" : "no") : value.toString().toUtf8();
    return mpv_set_property_string(m_mpv.get(), name.toUtf8().constData(), v.constData()) >= 0;
#else
    Q_UNUSED(name);
    Q_UNUSED(value);
    return false;
#endif
}

bool MpvItem::command(const QStringList &args)
{
#ifdef FLUX_HAS_MPV
    if (!m_mpv)
        return false;
    QList<QByteArray> utf8;
    std::vector<const char *> argv;
    for (const QString &arg : args)
        utf8.append(arg.toUtf8());
    for (const QByteArray &arg : utf8)
        argv.push_back(arg.constData());
    argv.push_back(nullptr);
    const int err = mpv_command(m_mpv.get(), argv.data());
    if (err < 0)
        qWarning() << "mpv command failed:" << args << mpv_error_string(err);
    return err >= 0;
#else
    Q_UNUSED(args);
    return false;
#endif
}

void MpvItem::updateBitrate()
{
    qint64 bytesPerSecond = static_cast<qint64>((m_videoBitrate + m_audioBitrate) / 8);
    if ((bytesPerSecond <= 0) && (m_fileSize > 0) && (m_duration > 0))
        bytesPerSecond = static_cast<qint64>(m_fileSize / m_duration);
    // the demuxer's figure jitters every second: only report real changes (> 10 %)
    if ((bytesPerSecond > 0) && ((m_bitrate == 0) || (std::abs(bytesPerSecond - m_bitrate) * 10 > m_bitrate)))
    {
        m_bitrate = bytesPerSecond;
        emit bitrateChanged();
    }
}

void MpvItem::onProperty(const QByteArray &name, const QVariant &value)
{
#ifdef FLUX_HAS_MPV
    if (name == "pause")
    {
        m_paused = value.toBool();
        emit pausedChanged();
    }
    else if (name == "time-pos")
    {
        m_position = value.toDouble();
        emit positionChanged();
    }
    else if (name == "duration")
    {
        m_duration = value.toDouble();
        emit durationChanged();
        updateBitrate();
    }
    else if (name == "demuxer-cache-time")
    {
        m_cachedUntil = value.toDouble();
        emit cacheChanged();
    }
    else if (name == "paused-for-cache")
    {
        m_buffering = value.toBool();
        emit cacheChanged();
    }
    else if (name == "seeking")
    {
        m_seeking = value.toBool();
        emit cacheChanged();
    }
    else if (name == "volume")
    {
        m_volume = qRound(value.toDouble());
        emit volumeChanged();
    }
    else if (name == "mute")
    {
        m_muted = value.toBool();
        emit volumeChanged();
    }
    else if (name == "track-list")
    {
        m_audioTracks = tracksOfType(value.toList(), u"audio"_s);
        m_subtitleTracks = tracksOfType(value.toList(), u"sub"_s);
        emit tracksChanged();
    }
    else if (name == "aid")
    {
        m_audioTrack = trackId(value);
        emit tracksChanged();
    }
    else if (name == "sid")
    {
        m_subtitleTrack = trackId(value);
        emit tracksChanged();
    }
    else if (name == "video-bitrate")
    {
        m_videoBitrate = value.toDouble();
        updateBitrate();
    }
    else if (name == "audio-bitrate")
    {
        m_audioBitrate = value.toDouble();
        updateBitrate();
    }
    else if (name == "file-size")
    {
        m_fileSize = value.toLongLong();
        updateBitrate();
    }
    else if (name == "eof-reached")
    {
        const bool eof = value.toBool();
        if (eof && !m_eof)
            emit endReached();
        m_eof = eof;
    }
#else
    Q_UNUSED(name);
    Q_UNUSED(value);
#endif
}

void MpvItem::processEvents()
{
#ifdef FLUX_HAS_MPV
    if (!m_mpv)
        return;
    while (true)
    {
        mpv_event *event = mpv_wait_event(m_mpv.get(), 0);
        if (event->event_id == MPV_EVENT_NONE)
            break;
        switch (event->event_id)
        {
        case MPV_EVENT_PROPERTY_CHANGE:
        {
            const auto *prop = static_cast<mpv_event_property *>(event->data);
            const QVariant value = (prop->format == MPV_FORMAT_NODE)
                ? nodeToVariant(static_cast<mpv_node *>(prop->data)) : QVariant();
            onProperty(QByteArray(prop->name), value);
            break;
        }
        case MPV_EVENT_FILE_LOADED:
            setMpvProperty(u"start"_s, u"none"_s);
            m_loaded = true;
            emit loadedChanged();
            emit fileLoaded();
            break;
        case MPV_EVENT_END_FILE:
        {
            const auto *end = static_cast<mpv_event_end_file *>(event->data);
            if (end->reason == MPV_END_FILE_REASON_ERROR)
                setError(QString::fromUtf8(mpv_error_string(end->error)));
            if (m_loaded)
            {
                m_loaded = false;
                emit loadedChanged();
            }
            break;
        }
        case MPV_EVENT_LOG_MESSAGE:
        {
            const auto *msg = static_cast<mpv_event_log_message *>(event->data);
            qWarning("mpv [%s] %s: %s", msg->prefix, msg->level, QByteArray(msg->text).trimmed().constData());
            break;
        }
        default:
            break;
        }
    }
#endif
}
