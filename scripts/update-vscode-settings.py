#!/usr/bin/env python3
"""Update managed appearance settings in a VS Code JSONC settings file."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


def set_string(content: str, key: str, value: str) -> str:
    encoded = json.dumps(value, ensure_ascii=False)
    pattern = re.compile(rf'("{re.escape(key)}"\s*:\s*)"(?:\\.|[^"\\])*"')
    updated, replacements = pattern.subn(
        lambda match: match.group(1) + encoded, content
    )
    if replacements:
        return updated

    opening_brace = content.find("{")
    if opening_brace == -1:
        raise ValueError("settings are not a JSON object")
    insertion = f'\n    "{key}": {encoded},'
    return content[: opening_brace + 1] + insertion + content[opening_brace + 1 :]


def main() -> int:
    if len(sys.argv) not in (3, 4):
        print(
            f"Usage: {Path(sys.argv[0]).name} SETTINGS_FILE FONT [THEME]",
            file=sys.stderr,
        )
        return 2

    settings = Path(sys.argv[1])
    font = sys.argv[2]
    theme = sys.argv[3] if len(sys.argv) == 4 else None

    if settings.exists():
        content = settings.read_text(encoding="utf-8")
    else:
        settings.parent.mkdir(parents=True, exist_ok=True)
        content = "{\n}\n"

    try:
        content = set_string(content, "editor.fontFamily", font)
        content = set_string(content, "terminal.integrated.fontFamily", font)
        if theme is not None:
            content = set_string(content, "workbench.colorTheme", theme)
    except ValueError:
        print(f"VS Code settings are not a JSON object: {settings}", file=sys.stderr)
        return 1

    # Write in place so VS Code notices the update and symlinks remain intact.
    settings.write_text(content, encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
