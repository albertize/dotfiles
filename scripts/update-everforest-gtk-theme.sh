#!/usr/bin/env bash

# Regenerate the complete Everforest GTK 3/4 theme from its pinned upstream source.
set -euo pipefail

readonly upstream_url='https://github.com/Fausto-Korpsvart/Everforest-GTK-Theme.git'
readonly upstream_commit='9b8be4d6648ae9eaae3dd550105081f8c9054825'
readonly sass_version='1.104.1'

repo_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
destination="$repo_dir/themes/everforest-green-dark"
temporary_directory=$(mktemp -d)
trap 'rm -rf -- "$temporary_directory"' EXIT
source_directory="$temporary_directory/source"
staged_theme="$temporary_directory/everforest-green-dark"

for command_name in git npx; do
  command -v "$command_name" >/dev/null 2>&1 || {
    printf '%s is required to update the Everforest GTK theme.\n' "$command_name" >&2
    exit 1
  }
done

git init -q "$source_directory"
git -C "$source_directory" remote add origin "$upstream_url"
git -C "$source_directory" fetch -q --depth 1 origin "$upstream_commit"
git -C "$source_directory" checkout -q --detach FETCH_HEAD

# Build the upstream green-accented, default-contrast dark variant used by the
# desktop profile. Keep this transformation explicit so regeneration is stable.
cp -- "$source_directory/themes/src/sass/_tweaks.scss" \
  "$source_directory/themes/src/sass/_tweaks-temp.scss"
sed -i \
  -e "s/\$theme: 'default'/\$theme: 'green'/" \
  "$source_directory/themes/src/sass/_tweaks-temp.scss"

mkdir -p -- "$staged_theme/gtk-3.0/assets" "$staged_theme/gtk-4.0/assets"
cp -a -- "$source_directory/themes/src/assets/gtk/assets-Green/." \
  "$staged_theme/gtk-3.0/assets/"
cp -a -- "$source_directory/themes/src/assets/gtk/scalable" \
  "$staged_theme/gtk-3.0/assets/scalable"
cp -a -- "$source_directory/themes/src/assets/gtk/scalable/." \
  "$staged_theme/gtk-4.0/assets/"
cp -a -- "$source_directory/themes/src/assets/gtk/thumbnails/thumbnail-Green-Dark.png" \
  "$staged_theme/gtk-3.0/thumbnail.png"
cp -a -- "$source_directory/themes/src/assets/gtk/thumbnails/thumbnail-Green-Dark.png" \
  "$staged_theme/gtk-4.0/thumbnail.png"

for gtk_version in 3.0 4.0; do
  input="$source_directory/themes/src/main/gtk-$gtk_version/gtk-Dark.scss"
  npx --yes "sass@$sass_version" --quiet --no-source-map --style=expanded \
    "$input" "$staged_theme/gtk-$gtk_version/gtk.css"
  sed -i -e 's/[[:space:]]\+$//' -e 's/^ *\t/\t/' \
    "$staged_theme/gtk-$gtk_version/gtk.css"
  if [[ $gtk_version == 3.0 ]]; then
    # GTK 3 does not recognize this GTK 4 layout property.
    sed -i \
      -e '/^[[:space:]]*border-spacing:/d' \
      -e '/url("assets\/scale-/s/\.svg"/\.png"/g' \
      -e 's|url("assets/cursor-handle|url("assets/scalable/cursor-handle|' \
      "$staged_theme/gtk-$gtk_version/gtk.css"
  fi
  ln -s -- gtk.css "$staged_theme/gtk-$gtk_version/gtk-dark.css"
done

cat > "$staged_theme/index.theme" <<'EOF'
[Desktop Entry]
Type=X-GNOME-Metatheme
Name=Everforest-Green-Dark
Comment=Complete Everforest green dark GTK theme
Encoding=UTF-8

[X-GNOME-Metatheme]
GtkTheme=Everforest-Green-Dark
MetacityTheme=Everforest-Green-Dark
IconTheme=Papirus-Dark-Everforest
CursorTheme=Adwaita
ButtonLayout=icon:minimize,maximize,close
EOF

cp -a "$source_directory/LICENSE" "$staged_theme/LICENSE"
rm -rf -- "$destination"
mv -- "$staged_theme" "$destination"
printf 'Updated %s from upstream commit %s.\n' "$destination" "$upstream_commit"
