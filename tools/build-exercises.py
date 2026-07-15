#!/usr/bin/env python3
"""Build desk-break exercise TSVs from the hasaneyldrm/exercises-dataset.

Input:  the dataset's data/exercises.json (path as argv[1], default /tmp/exds.json).
Output: plugins/desk-break/skills/desk-break/i18n/{en,zh}/exercises.tsv

Only the DATA is used (names, body parts, steps) — MIT licensed. Media (gif/image)
is referenced by RELATIVE PATH only; it is © Gym visual and is NOT copied here.

TSV columns (tab-separated), one row per no-equipment exercise:
    group \t name \t gif \t image \t step1¶step2¶...
`group` is a friendly body-part group (see GROUP_OF). Steps are joined by '¶'.
"""
import json
import os
import re
import sys

# Some "body weight" exercises still need apparatus (a pull-up bar, bench, dip
# station, rings, suspension straps, a box, a towel anchor, etc.). "body weight"
# in the source data means "no added load", not "no equipment". Exclude anything
# whose name implies gear beyond a wall/floor/desk.
NEEDS_EQUIPMENT = re.compile(
    r"strap|suspension|\btrx\b|\brings?\b|pull[\s-]?ups?|chin[\s-]?ups?|muscle[\s-]?ups?"
    r"|\bbars?\b|parallel|parallette|\bbench|\bbox(?:es)?\b|step[\s-]?ups?|\bdips?\b"
    r"|captain|roman chair|glute[\s-]?ham|\bghr\b|hyperextension|\bwheel|ab roller"
    r"|\blever\b|\bflag\b|towel",
    re.I,
)

# dataset body_part -> friendly focus group
GROUP_OF = {
    "waist": "core",
    "upper legs": "legs",
    "lower legs": "legs",
    "back": "back",
    "chest": "chest",
    "upper arms": "arms",
    "lower arms": "arms",
    "shoulders": "shoulders",
    "neck": "shoulders",
    "cardio": "cardio",
}
LANGS = ("en", "zh")


def clean(s: str) -> str:
    # TSV/'¶' safety: strip tabs, newlines, and the step separator from field text.
    return (s or "").replace("\t", " ").replace("\n", " ").replace("¶", "/").strip()


def main() -> int:
    src = sys.argv[1] if len(sys.argv) > 1 else "/tmp/exds.json"
    here = os.path.dirname(os.path.abspath(__file__))
    out_base = os.path.join(here, "..", "plugins", "desk-break", "skills", "desk-break", "i18n")

    data = json.load(open(src, encoding="utf-8"))
    bw = [
        x for x in data
        if x.get("equipment") == "body weight" and not NEEDS_EQUIPMENT.search(x.get("name", ""))
    ]

    counts = {}
    rows = {lang: [] for lang in LANGS}
    for x in bw:
        bp = x.get("body_part", "")
        group = GROUP_OF.get(bp, bp)
        name = clean(x.get("name", ""))
        gif = clean(x.get("gif_url") or "")
        image = clean(x.get("image") or "")
        steps = x.get("instruction_steps") or {}
        for lang in LANGS:
            st = steps.get(lang) or steps.get("en") or []
            joined = "¶".join(clean(s) for s in st if clean(s))
            rows[lang].append("\t".join([group, name, gif, image, joined]))
        counts[group] = counts.get(group, 0) + 1

    header = ("# desk-break exercises (no-equipment subset of hasaneyldrm/exercises-dataset, MIT).\n"
              "# Columns: group<TAB>name<TAB>gif<TAB>image<TAB>steps(joined by U+00B6).\n"
              "# Media (gif/image) is referenced by URL at display time; © Gym visual — https://gymvisual.com/\n")
    for lang in LANGS:
        d = os.path.normpath(os.path.join(out_base, lang))
        os.makedirs(d, exist_ok=True)
        with open(os.path.join(d, "exercises.tsv"), "w", encoding="utf-8") as f:
            f.write(header)
            f.write("\n".join(rows[lang]) + "\n")

    print(f"total body-weight: {len(bw)}")
    print("by group:", dict(sorted(counts.items(), key=lambda kv: -kv[1])))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
