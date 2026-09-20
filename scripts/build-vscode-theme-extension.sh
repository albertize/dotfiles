#!/usr/bin/env bash

# Build the local VS Code theme extension installed by install.sh.
set -euo pipefail

readonly vsce_version='3.6.2'
repo_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
source_directory="$repo_dir/vscode/dotfiles-theme"
default_theme="$repo_dir/themes/profiles/catppuccin-macchiato/vscode.json"
destination="$repo_dir/vscode/dotfiles-theme-1.0.1.vsix"
temporary_archive=$(mktemp)
trap 'rm -f -- "$temporary_archive"' EXIT

for command_name in npx cp; do
  command -v "$command_name" >/dev/null 2>&1 || {
    printf '%s is required to build the VS Code theme extension.\n' \
      "$command_name" >&2
    exit 1
  }
done

# The packaged default only covers the short interval before apply-theme.sh
# replaces the runtime copy with the currently selected profile.
cp -- "$default_theme" "$source_directory/themes/dotfiles-color-theme.json"
(
  cd -- "$source_directory"
  npx --yes "@vscode/vsce@$vsce_version" package \
    --allow-missing-repository --out "$temporary_archive"
)
mv -- "$temporary_archive" "$destination"
trap - EXIT
printf 'Built %s with @vscode/vsce %s.\n' "$destination" "$vsce_version"
