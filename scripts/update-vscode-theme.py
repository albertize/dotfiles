#!/usr/bin/env python3
"""Update only VS Code's color-theme setting in a JSONC settings file."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 3:
        print(f"Usage: {Path(sys.argv[0]).name} SETTINGS_FILE THEME", file=sys.stderr)
        return 2

    settings = Path(sys.argv[1])
    theme = sys.argv[2]
    encoded_theme = json.dumps(theme, ensure_ascii=False)
    pattern = re.compile(
        r'("workbench\.colorTheme"\s*:\s*)"(?:\\.|[^"\\])*"'
    )

    if settings.exists():
        content = settings.read_text(encoding="utf-8")
        updated, replacements = pattern.subn(
            lambda match: match.group(1) + encoded_theme, content
        )
        if replacements == 0:
            opening_brace = content.find("{")
            if opening_brace == -1:
                print(f"VS Code settings are not a JSON object: {settings}", file=sys.stderr)
                return 1
            insertion = f'\n    "workbench.colorTheme": {encoded_theme},'
            updated = content[: opening_brace + 1] + insertion + content[opening_brace + 1 :]
    else:
        settings.parent.mkdir(parents=True, exist_ok=True)
        updated = f'{{\n    "workbench.colorTheme": {encoded_theme}\n}}\n'

    # Write in place so VS Code notices the update and existing symlinks remain intact.
    settings.write_text(updated, encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
