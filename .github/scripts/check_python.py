#!/usr/bin/env python3
"""Overí syntax Python súborov bez toho, aby čokoľvek zapisoval na disk.

`py_compile` by vytvoril `__pycache__` v pracovnom strome, `ast.parse` len
prečíta text — v CI to je jedno, ale lokálne to nechá repo čisté.

Použitie: python3 check_python.py súbor1 súbor2 ...
"""

from __future__ import annotations

import ast
import pathlib
import sys


def main(argv: list[str]) -> int:
    failures = []
    for name in argv:
        try:
            ast.parse(pathlib.Path(name).read_text(encoding="utf-8"), name)
        except (OSError, UnicodeDecodeError, SyntaxError) as error:
            failures.append(f"{name}: {error}")

    for failure in failures:
        print(failure, file=sys.stderr)
    print(f"{len(argv) - len(failures)} súborov v poriadku, {len(failures)} chýb")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
