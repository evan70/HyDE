#!/usr/bin/env python3
"""Prejde JSON a JSONC súbory a overí, že sa dajú naparsovať.

Waybar, fastfetch aj schémy HyDE používajú JSONC — komentáre `//` a `/* */`
a čiarky navyše na konci zoznamov. `json.loads` na ne nestačí, preto sa pred
parsovaním komentáre odstránia (mimo reťazcov) a visiace čiarky zahoja.

Použitie: python3 check_jsonc.py súbor1 súbor2 ...
"""

from __future__ import annotations

import json
import pathlib
import re
import sys

TRAILING_COMMA = re.compile(r",(\s*[}\]])")


def strip_comments(text: str) -> str:
    """Odstráni komentáre; obsah reťazcov (vrátane URL s //) nechá tak."""
    result = []
    index, length = 0, len(text)
    in_string = False
    escaped = False
    while index < length:
        char = text[index]
        if in_string:
            result.append(char)
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
            index += 1
            continue
        if char == '"':
            in_string = True
            result.append(char)
            index += 1
            continue
        if text.startswith("//", index):
            while index < length and text[index] != "\n":
                index += 1
            continue
        if text.startswith("/*", index):
            end = text.find("*/", index + 2)
            index = length if end == -1 else end + 2
            continue
        result.append(char)
        index += 1
    return "".join(result)


def main(argv: list[str]) -> int:
    failures = []
    for name in argv:
        path = pathlib.Path(name)
        try:
            text = path.read_text(encoding="utf-8")
            json.loads(TRAILING_COMMA.sub(r"\1", strip_comments(text)))
        except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
            failures.append(f"{name}: {error}")

    for failure in failures:
        print(failure, file=sys.stderr)
    print(f"{len(argv) - len(failures)} súborov v poriadku, {len(failures)} chýb")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
