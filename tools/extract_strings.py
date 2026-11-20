"""Lists every context.tr/trf key with its English text, and reports keys
missing from the Arabic/Hebrew tables.

  python tools/extract_strings.py            # key<TAB>English for all keys
  python tools/extract_strings.py --missing  # keys missing per language
"""
import os
import re
import sys

PAT = re.compile(r"\btrf?\(\s*'([\w.]+)'\s*,\s*(?:'((?:[^'\\]|\\.)*)'|\"((?:[^\"\\]|\\.)*)\")", re.S)


def collect():
    keys = {}
    for dp, _, fs in os.walk('lib'):
        for fn in fs:
            if fn.endswith('.dart') and not fn.startswith('l10n_'):
                src = open(os.path.join(dp, fn), encoding='utf8').read()
                for m in PAT.finditer(src):
                    en = m.group(2) if m.group(2) is not None else m.group(3)
                    if m.group(1) in keys and keys[m.group(1)] != en:
                        print('CONFLICT', m.group(1), '|', keys[m.group(1)], '|', en, file=sys.stderr)
                    keys[m.group(1)] = en
    return keys


def table(fn):
    p = os.path.join('lib', 'app', fn)
    if not os.path.exists(p):
        return set()
    return set(re.findall(r"^\s*'([\w.]+)':", open(p, encoding='utf8').read(), re.M))


if __name__ == '__main__':
    keys = collect()
    if '--missing' in sys.argv:
        for lang in ['ar', 'he']:
            t = table(f'l10n_{lang}.dart')
            miss = [k for k in keys if k not in t]
            extra = [k for k in t if k not in keys]
            print(lang, 'missing', len(miss), miss, 'unused', extra)
    else:
        for k in sorted(keys):
            print(f'{k}\t{keys[k]}')
        print(len(keys), 'keys', file=sys.stderr)
