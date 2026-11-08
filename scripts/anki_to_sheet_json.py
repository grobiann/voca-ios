"""Extract text-only CardVoca rows from locally supplied Anki packages.

The output is a temporary intermediate. It excludes sound, images, long grammar
descriptions and workbook/media metadata. No source content belongs in Git.
"""

import html
import argparse
import json
import re
import sqlite3
import subprocess
import tempfile
import unicodedata
import zipfile
from collections import defaultdict
from pathlib import Path

SOURCE = "https://gall.dcinside.com/mgallery/board/view/?id=jlpt&no=70170"

def clean(value):
    value = re.sub(r"\[sound:[^]]+\]", "", value or "")
    value = re.sub(r"<br\s*/?>", " ", value, flags=re.I)
    value = re.sub(r"<[^>]*>", "", value)
    value = html.unescape(value)
    return re.sub(r"\s+", " ", value).strip()


def choose(fields, *names):
    for name in names:
        if fields.get(name.lower()):
            return fields[name.lower()]
    return ""


def normalized_note(fields, filename):
    japanese = choose(fields, "vocabulary-kanji", "kanji", "expression", "sentence_japanese", "furigana")
    korean = choose(fields, "sentence_korean", "meaning")
    reading = choose(fields, "vocabulary-kana", "kana", "furigana", "reading")
    english = choose(fields, "vocabulary-english")
    normalized_filename = unicodedata.normalize("NFC", filename)
    kind = "sentence" if "NHK" in normalized_filename or "문형" in normalized_filename or "毎日の" in normalized_filename else "word"
    if "毎日の" in filename:
        japanese = choose(fields, "sentence_japanese")
        korean = choose(fields, "sentence_korean")
    if "Core 2k_6k" in filename:
        korean = ""
    bracket = re.match(r"^(.*?)\[([^]]+)\]$", japanese)
    if bracket:
        japanese = bracket.group(1).strip()
        if not reading:
            reading = bracket.group(2).strip()
    reading = re.sub(r"\[([^]]+)\]", r"\1", reading)
    japanese = clean(japanese)
    korean = clean(korean)
    reading = clean(reading)
    english = clean(english)
    if not japanese or (not korean and not english):
        return None
    return japanese, reading, korean, english, kind


def process(path):
    with zipfile.ZipFile(path) as package:
        item = "collection.anki21b" if "collection.anki21b" in package.namelist() else "collection.anki2"
        raw = package.read(item)
    if item.endswith("21b"):
        raw = subprocess.run(["zstd", "-dc"], input=raw, capture_output=True, check=True).stdout
    with tempfile.NamedTemporaryFile(suffix=".sqlite") as temporary:
        temporary.write(raw)
        temporary.flush()
        connection = sqlite3.connect(temporary.name)
        connection.create_collation("unicase", lambda a, b: (a.casefold() > b.casefold()) - (a.casefold() < b.casefold()))
        field_names = defaultdict(dict)
        for model, index, name in connection.execute("select ntid,ord,name from fields"):
            field_names[model][index] = name.lower()
        decks = {identifier: name.split("\x1f")[-1] for identifier, name in connection.execute("select id,name from decks")}
        note_decks = defaultdict(set)
        for note_id, deck_id in connection.execute("select nid,did from cards"):
            note_decks[note_id].add(deck_id)
        grouped = defaultdict(list)
        skipped = 0
        for note_id, model, raw_fields in connection.execute("select id,mid,flds from notes order by id"):
            fields = {name: clean(raw_fields.split("\x1f")[index]) for index, name in field_names[model].items() if index < len(raw_fields.split("\x1f"))}
            result = normalized_note(fields, path.name)
            if not result:
                skipped += 1
                continue
            deck_names = sorted(decks[deck_id] for deck_id in note_decks[note_id] if deck_id in decks and decks[deck_id] not in {"日本語", "Default"})
            deck = deck_names[0] if deck_names else path.stem
            grouped[deck].append([str(note_id), *result])
        connection.close()
    sheets = []
    for deck_name, notes in sorted(grouped.items()):
        rows = []
        seen = set()
        for note_id, japanese, reading, korean, english, kind in notes:
            if note_id in seen:
                continue
            seen.add(note_id)
            stack = f"{deck_name} {len(rows) // 20 + 1:03d}"
            rows.append([stack, note_id, japanese, reading, korean, english, kind, SOURCE])
        if rows:
            sheets.append({"name": deck_name[:70], "rows": rows})
    return {"name": path.stem.replace("日本語__", ""), "sheets": sheets, "skipped": skipped}


def main():
    parser = argparse.ArgumentParser(description="Convert text fields from local .apkg files into CardVoca sheet rows")
    parser.add_argument("directory", type=Path, help="Directory containing .apkg files")
    parser.add_argument("output", type=Path, help="Output JSON path")
    args = parser.parse_args()
    packages = [process(path) for path in sorted(args.directory.glob("*.apkg"))]
    args.output.write_text(json.dumps(packages, ensure_ascii=False), encoding="utf-8")
    for package in packages:
        print(package["name"], "rows", sum(len(sheet["rows"]) for sheet in package["sheets"]),
              "tabs", len(package["sheets"]), "skipped", package["skipped"])


if __name__ == "__main__":
    main()
