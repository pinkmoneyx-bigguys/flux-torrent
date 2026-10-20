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

#pragma once

#include <memory>

#include <QString>
#include <QStringList>
#include <QVariant>
#include <QVariantList>
#include <QtQmlIntegration/qqmlintegration.h>

#ifdef FLUX_HAS_MPV
#include <QQuickFramebufferObject>
using MpvItemBase = QQuickFramebufferObject;
#else
#include <QQuickItem>
using MpvItemBase = QQuickItem;
#endif

struct mpv_handle;

// The built-in video player: libmpv drawn through its render API into a Qt Quick framebuffer object
// (OpenGL scene graph only). Set `source` (a file URL or the stream URL) and optionally `startPosition`;
// state comes back through the properties. Without libmpv in the build (FLUX_HAS_MPV unset) it is an
// empty item with available == false.
//
// Lifetime: the mpv handle is shared with the renderer (render thread), which frees its render context
// before the last reference destroys mpv. mpv callbacks arrive on mpv's threads and only queue work onto
// the GUI thread.
class MpvItem : public MpvItemBase
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(bool available READ isAvailable CONSTANT FINAL)
    Q_PROPERTY(QString source READ source WRITE setSource NOTIFY sourceChanged FINAL)
    // Seconds to start the next source at (0: from the start)
    Q_PROPERTY(double startPosition READ startPosition WRITE setStartPosition NOTIFY startPositionChanged FINAL)
    Q_PROPERTY(bool paused READ isPaused WRITE setPaused NOTIFY pausedChanged FINAL)
    Q_PROPERTY(double position READ position NOTIFY positionChanged FINAL)
    Q_PROPERTY(double duration READ duration NOTIFY durationChanged FINAL)
    // How far mpv has the file read ahead (seconds), and whether it waits for data now
    Q_PROPERTY(double cachedUntil READ cachedUntil NOTIFY cacheChanged FINAL)
    Q_PROPERTY(bool buffering READ isBuffering NOTIFY cacheChanged FINAL)
    Q_PROPERTY(bool seeking READ isSeeking NOTIFY cacheChanged FINAL)
    Q_PROPERTY(bool loaded READ isLoaded NOTIFY loadedChanged FINAL)
    Q_PROPERTY(int volume READ volume WRITE setVolume NOTIFY volumeChanged FINAL)
    Q_PROPERTY(bool muted READ isMuted WRITE setMuted NOTIFY volumeChanged FINAL)
    // [{id, title, lang, codec, external}]
    Q_PROPERTY(QVariantList audioTracks READ audioTracks NOTIFY tracksChanged FINAL)
    Q_PROPERTY(QVariantList subtitleTracks READ subtitleTracks NOTIFY tracksChanged FINAL)
    // Track ids; 0 is "off"
    Q_PROPERTY(int audioTrack READ audioTrack WRITE setAudioTrack NOTIFY tracksChanged FINAL)
    Q_PROPERTY(int subtitleTrack READ subtitleTrack WRITE setSubtitleTrack NOTIFY tracksChanged FINAL)
    // Media bitrate in bytes per second (0 until known), for the stream's read-ahead window
    Q_PROPERTY(qint64 bitrate READ bitrate NOTIFY bitrateChanged FINAL)
    // Hardware decoding ("auto-safe" or "no"); applies to the next file
    Q_PROPERTY(QString hwdec READ hwdec WRITE setHwdec NOTIFY hwdecChanged FINAL)
    Q_PROPERTY(QString error READ error NOTIFY errorChanged FINAL)

public:
    explicit MpvItem(QQuickItem *parent = nullptr);
    ~MpvItem() override;

#ifdef FLUX_HAS_MPV
    Renderer *createRenderer() const override;
#endif

    static bool isAvailable();

    QString source() const;
    void setSource(const QString &source);
    double startPosition() const;
    void setStartPosition(double seconds);
    bool isPaused() const;
    void setPaused(bool paused);
    double position() const;
    double duration() const;
    double cachedUntil() const;
    bool isBuffering() const;
    bool isSeeking() const;
    bool isLoaded() const;
    int volume() const;
    void setVolume(int volume);
    bool isMuted() const;
    void setMuted(bool muted);
    QVariantList audioTracks() const;
    QVariantList subtitleTracks() const;
    int audioTrack() const;
    void setAudioTrack(int id);
    int subtitleTrack() const;
    void setSubtitleTrack(int id);
    qint64 bitrate() const;
    QString hwdec() const;
    void setHwdec(const QString &hwdec);
    QString error() const;

    Q_INVOKABLE void togglePause();
    Q_INVOKABLE void seek(double seconds);
    Q_INVOKABLE void seekRelative(double seconds);
    Q_INVOKABLE void stop();
    // An external subtitle file (an .srt/.ass of the torrent)
    Q_INVOKABLE void addSubtitle(const QString &path);
    Q_INVOKABLE QVariant mpvProperty(const QString &name) const;
    Q_INVOKABLE bool setMpvProperty(const QString &name, const QVariant &value);
    Q_INVOKABLE bool command(const QStringList &args);

    // Shared with the renderer, which lives on the render thread and may outlive the item
    std::shared_ptr<mpv_handle> handle() const;

signals:
    void sourceChanged();
    void startPositionChanged();
    void pausedChanged();
    void positionChanged();
    void durationChanged();
    void cacheChanged();
    void loadedChanged();
    void volumeChanged();
    void tracksChanged();
    void bitrateChanged();
    void hwdecChanged();
    void errorChanged();
    void fileLoaded();
    // Playback reached the end of the file (it stays on the last frame)
    void endReached();
    void rendererReady();

private:
    void onRendererReady();
    void processEvents();
    void onProperty(const QByteArray &name, const QVariant &value);
    void loadSource();
    void updateBitrate();
    void setError(const QString &error);

    std::shared_ptr<mpv_handle> m_mpv;
    QString m_source;
    double m_startPosition = 0;
    bool m_rendererReady = false;
    bool m_loaded = false;
    bool m_paused = false;
    double m_position = 0;
    double m_duration = 0;
    double m_cachedUntil = 0;
    bool m_buffering = false;
    bool m_seeking = false;
    int m_volume = 100;
    bool m_muted = false;
    QVariantList m_audioTracks;
    QVariantList m_subtitleTracks;
    int m_audioTrack = 0;
    int m_subtitleTrack = 0;
    double m_videoBitrate = 0;
    double m_audioBitrate = 0;
    qint64 m_fileSize = 0;
    qint64 m_bitrate = 0;
    QString m_hwdec = QStringLiteral("auto-safe");
    QString m_error;
    bool m_eof = false;
};
