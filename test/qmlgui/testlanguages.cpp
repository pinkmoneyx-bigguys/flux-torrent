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

#include <QFile>
#include <QHash>
#include <QObject>
#include <QRegularExpression>
#include <QStringList>
#include <QTest>
#include <QXmlStreamReader>

#include "qmlgui/backend/languages.h"

using namespace Qt::Literals::StringLiterals;

class TestLanguages final : public QObject
{
    Q_OBJECT
    Q_DISABLE_COPY_MOVE(TestLanguages)

public:
    TestLanguages() = default;

private:
    struct Message
    {
        QString context;
        QString source;
        bool numerus = false;
        bool unfinished = false;
        QStringList translations;
    };

    static QList<Message> readTs(const QString &path)
    {
        QList<Message> messages;
        QFile file {path};
        if (!file.open(QIODevice::ReadOnly))
            return messages;
        QXmlStreamReader xml {&file};
        QString context;
        Message current;
        while (!xml.atEnd())
        {
            xml.readNext();
            if (!xml.isStartElement())
            {
                if (xml.isEndElement() && (xml.name() == u"message"))
                    messages.append(current);
                continue;
            }
            const QStringView name = xml.name();
            if (name == u"name")
                context = xml.readElementText();
            else if (name == u"message")
            {
                current = {};
                current.context = context;
                current.numerus = (xml.attributes().value(u"numerus") == u"yes");
            }
            else if (name == u"source")
                current.source = xml.readElementText();
            else if (name == u"translation")
            {
                current.unfinished = (xml.attributes().value(u"type") == u"unfinished");
                if (!current.numerus)
                    current.translations = {xml.readElementText()};
            }
            else if (name == u"numerusform")
                current.translations.append(xml.readElementText());
        }
        return messages;
    }

    static QStringList placeholders(const QString &text, const bool withCount)
    {
        static const QRegularExpression re {u"%(\\d+|n)"_s};
        QStringList found;
        for (auto it = re.globalMatch(text); it.hasNext();)
        {
            const QString p = it.next().captured();
            if (withCount || (p != u"%n"))
                found.append(p);
        }
        found.sort();
        return found;
    }

private slots:
    void choiceWins()
    {
        QCOMPARE(Languages::resolve(u"de"_s, {u"ru-RU"_s}), u"de"_s);
        QCOMPARE(Languages::resolve(u"en"_s, {u"ru-RU"_s}), u"en"_s);
    }

    void systemLanguage()
    {
        QCOMPARE(Languages::resolve({}, {u"ru-RU"_s, u"ru"_s}), u"ru"_s);
        QCOMPARE(Languages::resolve({}, {u"uk-UA"_s}), u"uk"_s);
        QCOMPARE(Languages::resolve({}, {u"de-AT"_s}), u"de"_s);
        QCOMPARE(Languages::resolve({}, {u"pt-PT"_s}), u"pt_BR"_s);
        QCOMPARE(Languages::resolve({}, {u"zh-CN"_s}), u"zh_CN"_s);
        QCOMPARE(Languages::resolve({}, {u"zh-Hans-SG"_s}), u"zh_CN"_s);
        // the next one the user wants when the first isn't translated
        QCOMPARE(Languages::resolve({}, {u"be-BY"_s, u"ru-RU"_s}), u"ru"_s);
    }

    void untranslatedSystemIsEnglish()
    {
        QCOMPARE(Languages::resolve({}, {u"ja-JP"_s}), u"en"_s);
        // traditional Chinese is not the simplified translation
        QCOMPARE(Languages::resolve({}, {u"zh-TW"_s}), u"en"_s);
        QCOMPARE(Languages::resolve({}, {u"zh-Hant-HK"_s}), u"en"_s);
        // a qBittorrent choice Flux has no translation for
        QCOMPARE(Languages::resolve(u"ja"_s, {u"ja-JP"_s}), u"en"_s);
        QCOMPARE(Languages::resolve({}, {}), u"en"_s);
    }

    void namesInTheirOwnLanguage()
    {
        QCOMPARE(Languages::nativeName(u"ru"_s), u"Русский"_s);
        QCOMPARE(Languages::nativeName(u"zh_CN"_s), u"简体中文"_s);
        for (const QString &code : Languages::supported())
            QVERIFY2(Languages::nativeName(code) != code, qUtf8Printable(code));
    }

    // Each translation is whole and keeps the placeholders: a missing %1 shows the raw template, a
    // missing translation shows English in the middle of another language
    void translationsComplete_data()
    {
        QTest::addColumn<QString>("code");
        for (const QString &code : Languages::supported())
        {
            if (code != u"en")
                QTest::newRow(qUtf8Printable(code)) << code;
        }
    }

    void translationsComplete()
    {
        QFETCH(QString, code);
        static const QHash<QString, int> forms {
            {u"ru"_s, 3}, {u"uk"_s, 3}, {u"pl"_s, 3}, {u"de"_s, 2}, {u"es"_s, 2}, {u"fr"_s, 2}, {u"pt_BR"_s, 2},
            {u"zh_CN"_s, 1}};

        const QList<Message> messages = readTs(QStringLiteral(FLUX_I18N_DIR) + u"/flux_" + code + u".ts");
        QVERIFY2(messages.size() > 500, qUtf8Printable(u"%1 messages"_s.arg(messages.size())));
        QStringList problems;
        for (const Message &m : messages)
        {
            const QString where = u"[%1] %2"_s.arg(m.context, m.source.left(60));
            if (m.unfinished)
            {
                problems.append(u"unfinished " + where);
                continue;
            }
            if (m.numerus && (m.translations.size() != forms.value(code)))
                problems.append(u"%1 plural forms: "_s.arg(m.translations.size()) + where);
            for (const QString &t : m.translations)
            {
                if (t.trimmed().isEmpty())
                    problems.append(u"empty " + where);
                else if (placeholders(t, !m.numerus) != placeholders(m.source, !m.numerus))
                    problems.append(u"placeholders: " + where + u" → " + t);
            }
        }
        QVERIFY2(problems.isEmpty(), qUtf8Printable(problems.mid(0, 20).join(u'\n')));
    }

    // English is the source language, but "%n file(s)" needs its two forms from a translation too
    void englishPlurals()
    {
        const QList<Message> messages = readTs(QStringLiteral(FLUX_I18N_DIR) + u"/flux_en.ts");
        int plurals = 0;
        for (const Message &m : messages)
        {
            if (!m.numerus)
                continue;
            ++plurals;
            QVERIFY2(!m.unfinished && (m.translations.size() == 2), qUtf8Printable(m.source));
            for (const QString &t : m.translations)
                QVERIFY2(!t.contains(u"(s)"), qUtf8Printable(t));
        }
        QVERIFY(plurals > 5);
    }
};

QTEST_APPLESS_MAIN(TestLanguages)
#include "testlanguages.moc"
