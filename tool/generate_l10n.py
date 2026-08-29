#!/usr/bin/env python3
"""Generate the ARB translation files from the extracted design copy.

The design prototype is the source of truth for user-facing wording, so the
English/Amharic pairs in design/extracted/strings.json are compiled straight
into lib/l10n/app_en.arb and app_am.arb rather than being retyped. Strings the
design never had -- error copy, auth failures, generic actions -- live in
tool/l10n_extra.json and are merged in.

Neither ARB file should be hand-edited: re-run this instead.

Usage:  python3 tool/generate_l10n.py
"""

import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DESIGN = os.path.join(ROOT, "design", "extracted", "strings.json")
EXTRA = os.path.join(ROOT, "tool", "l10n_extra.json")
OUT = os.path.join(ROOT, "lib", "l10n")

# Dart reserved words cannot be used as identifiers, and a few AppLocalizations
# members would be shadowed by a getter of the same name. Either case is a hard
# error at codegen time, so both are checked here rather than discovered by the
# analyzer afterwards.
DART_KEYWORDS = {
    "abstract", "as", "assert", "async", "await", "break", "case", "catch",
    "class", "const", "continue", "covariant", "default", "deferred", "do",
    "dynamic", "else", "enum", "export", "extends", "extension", "external",
    "factory", "false", "final", "finally", "for", "function", "get", "hide",
    "if", "implements", "import", "in", "interface", "is", "late", "library",
    "mixin", "new", "null", "on", "operator", "part", "required", "rethrow",
    "return", "set", "show", "static", "super", "switch", "sync", "this",
    "throw", "true", "try", "typedef", "var", "void", "while", "with", "yield",
}

APP_LOCALIZATIONS_MEMBERS = {
    "of", "delegate", "supportedLocales", "localeName",
    "hashCode", "runtimeType", "toString", "noSuchMethod",
}

RESERVED = DART_KEYWORDS | APP_LOCALIZATIONS_MEMBERS

# Design keys renamed to dodge those collisions. The English and Amharic copy
# is untouched -- only the identifier changes.
RENAMES = {
    "of": "ofWord",
    "continue": "continueLabel",
}


def load(path):
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def main():
    design = load(DESIGN)
    extra = {k: v for k, v in load(EXTRA).items() if not k.startswith("_")}

    entries = {}
    sources = {}
    for origin, table in (("design", design), ("app", extra)):
        for key, pair in table.items():
            key = RENAMES.get(key, key)
            if key in RESERVED:
                raise SystemExit(
                    "key %r is a Dart keyword or an AppLocalizations member; "
                    "add it to RENAMES in tool/generate_l10n.py" % key
                )
            if key in entries:
                raise SystemExit(
                    "key %r defined twice (%s and %s)" % (key, sources[key], origin)
                )
            entries[key] = pair
            sources[key] = origin

    os.makedirs(OUT, exist_ok=True)

    for locale, field in (("en", "en"), ("am", "am")):
        arb = {"@@locale": locale}
        for key in sorted(entries):
            arb[key] = entries[key][field]
            if locale == "en":
                arb["@" + key] = {
                    "description": "%s copy" % (
                        "Design prototype" if sources[key] == "design" else "Application"
                    ),
                }
        path = os.path.join(OUT, "app_%s.arb" % locale)
        with open(path, "w", encoding="utf-8") as fh:
            json.dump(arb, fh, ensure_ascii=False, indent=2)
            fh.write("\n")
        print("%-22s %d strings" % (os.path.relpath(path, ROOT), len(entries)))

    design_count = sum(1 for k in sources.values() if k == "design")
    print("  %d from the design, %d added by the app"
          % (design_count, len(entries) - design_count))


if __name__ == "__main__":
    sys.exit(main())
