#!/usr/bin/env python3
"""Checks Flux's UI translations (src/qmlgui/i18n/flux_*.ts): every message translated, the placeholders
(%1, %2…, %n) kept, the right number of plural forms, a trailing ellipsis and HTML tags kept. flux_en.ts holds
only the English plural forms, so only those are checked there. Exits non-zero on any problem."""
import pathlib
import re
import sys
import xml.etree.ElementTree as ET

I18N = pathlib.Path(__file__).resolve().parent.parent / 'src' / 'qmlgui' / 'i18n'
PLURAL_FORMS = {'en': 2, 'ru': 3, 'uk': 3, 'pl': 3, 'de': 2, 'es': 2, 'fr': 2, 'pt_BR': 2, 'zh_CN': 1}


def placeholders(text, with_count=True):
    found = re.findall(r'%(?:\d+|n)', text)
    return sorted(p for p in found if with_count or p != '%n')


def tags(text):
    return sorted(re.findall(r'</?[a-zA-Z][^>]*>', text))


def check(path):
    lang = path.stem[len('flux_'):]
    problems = []
    for context in ET.parse(path).getroot().iter('context'):
        name = context.findtext('name')
        for message in context.iter('message'):
            source = message.findtext('source') or ''
            numerus = message.get('numerus') == 'yes'
            translation = message.find('translation')
            where = f'[{name}] {source[:60]!r}'
            if lang == 'en' and not numerus:
                continue
            if translation is None or translation.get('type') in ('unfinished', 'vanished', 'obsolete'):
                problems.append(f'not translated: {where}')
                continue
            texts = [f.text or '' for f in translation.findall('numerusform')] if numerus else [translation.text or '']
            if numerus and len(texts) != PLURAL_FORMS.get(lang, len(texts)):
                problems.append(f'{len(texts)} plural forms, {PLURAL_FORMS[lang]} expected: {where}')
            for text in texts:
                if not text.strip():
                    problems.append(f'empty: {where}')
                elif placeholders(text, not numerus) != placeholders(source, not numerus):
                    problems.append(f'placeholders differ: {where} -> {text!r}')
                elif tags(text) != tags(source):
                    problems.append(f'HTML tags differ: {where} -> {text!r}')
                elif source.endswith('…') and not text.endswith('…'):
                    problems.append(f'lost the "…": {where} -> {text!r}')
    return problems


def main():
    sys.stdout.reconfigure(encoding='utf-8')
    bad = 0
    for path in sorted(I18N.glob('flux_*.ts')):
        problems = check(path)
        bad += len(problems)
        print(f'{path.name}: {"ok" if not problems else f"{len(problems)} problem(s)"}')
        for problem in problems[:50]:
            print('   ', problem)
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
