#!/usr/bin/env python3
"""Checks the README and its translations (docs/i18n/README.*.md): relative links and images exist, in-page
anchors match a heading (GitHub's rules), and the language switcher links every language and marks the file's
own. Exits non-zero on any problem."""
import os
import pathlib
import re
import sys
import unicodedata

ROOT = pathlib.Path(__file__).resolve().parent.parent
FILES = {
    'English': 'README.md',
    'Русский': 'docs/i18n/README.ru.md',
    'Українська': 'docs/i18n/README.uk.md',
    'Deutsch': 'docs/i18n/README.de.md',
    'Español': 'docs/i18n/README.es.md',
    'Français': 'docs/i18n/README.fr.md',
    'Português': 'docs/i18n/README.pt-BR.md',
    'Polski': 'docs/i18n/README.pl.md',
    '简体中文': 'docs/i18n/README.zh-CN.md',
}


def anchor(heading):
    """A heading's anchor as GitHub makes it: lower case, punctuation and emoji dropped, spaces as hyphens."""
    kept = [ch for ch in heading.strip().lower()
            if ch in ' -_' or unicodedata.category(ch)[0] in 'LN' or unicodedata.category(ch) in ('Mn', 'Mc')]
    return ''.join(kept).replace(' ', '-')


def check(name, relative):
    path = ROOT / relative
    if not path.exists():
        return [f'missing: {relative}']
    text = path.read_text(encoding='utf-8')
    body = re.sub(r'```.*?```', '', text, flags=re.S)
    anchors = {anchor(re.sub(r'<[^>]+>', '', h)) for h in re.findall(r'^#{1,6}\s+(.+)$', body, re.M)}
    anchors |= {anchor(h) for h in re.findall(r'<h[1-6][^>]*>(.*?)</h[1-6]>', body)}
    problems = []
    for link in re.findall(r'\]\(([^)\s]+)\)', body) + re.findall(r'(?:src|href)="([^"]+)"', body):
        if link.startswith(('http://', 'https://', 'mailto:')):
            continue
        if link.startswith('#'):
            if link[1:] not in anchors:
                problems.append(f'no heading for {link}')
        elif not (path.parent / link.split('#')[0]).exists():
            problems.append(f'broken link: {link}')
    switcher = re.search(r'<p align="center">(.*?)</p>', text, re.S)
    switcher = switcher.group(1) if switcher else ''
    if f'<b>{name}</b>' not in switcher:
        problems.append(f'the switcher does not mark {name}')
    for other, other_file in FILES.items():
        if other == name:
            continue
        target = pathlib.Path(os.path.relpath(ROOT / other_file, path.parent)).as_posix()
        if f'href="{target}">{other}</a>' not in switcher:
            problems.append(f'the switcher has no link {target} for {other}')
    return problems


def main():
    sys.stdout.reconfigure(encoding='utf-8')
    bad = 0
    for name, relative in FILES.items():
        problems = check(name, relative)
        bad += len(problems)
        print(f'{relative}: {"ok" if not problems else f"{len(problems)} problem(s)"}')
        for problem in problems:
            print('   ', problem)
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
