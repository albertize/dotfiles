#!/usr/bin/env bash

# Sway autotiling: each new window occupies 38.2% of the current container
# and prepares the next split along its longest side.
set -uo pipefail

readonly minor_thousandths=382
readonly golden_ratio_milli=1618

command -v jq >/dev/null 2>&1 || {
  printf 'golden-layout: jq is not installed\n' >&2
  exit 1
}

container_info() {
  local id=$1

  swaymsg -r -t get_tree | jq -r --argjson id "$id" '
    def locate($wanted):
      . as $parent
      | ((.nodes // []) + (.floating_nodes // []))[] as $child
      | if $child.id == $wanted then
          {parent: $parent, node: $child}
        else
          ($child | locate($wanted))
        end;

    locate($id)
    | [
        .parent.layout,
        (.parent.nodes | length),
        .node.floating,
        .node.rect.width,
        .node.rect.height,
        .parent.rect.width,
        .parent.rect.height
      ]
    | @tsv
  ' | head -n 1
}

orient_container() {
  local id=$1
  local info layout siblings floating width height parent_width parent_height

  info=$(container_info "$id")
  [[ -n $info ]] || return 0
  IFS=$'\t' read -r layout siblings floating width height parent_width parent_height <<< "$info"

  # Floating windows do not participate in automatic layout.
  [[ $floating == auto_off || $floating == user_off ]] || return 0
  [[ $width =~ ^[0-9]+$ && $height =~ ^[0-9]+$ ]] || return 0

  if (( width * 1000 >= height * golden_ratio_milli )); then
    swaymsg -q "[con_id=$id] split h"
  else
    swaymsg -q "[con_id=$id] split v"
  fi
}

resize_new_container() {
  local id=$1
  local info layout siblings floating width height parent_width parent_height target

  info=$(container_info "$id")
  [[ -n $info ]] || return 0
  IFS=$'\t' read -r layout siblings floating width height parent_width parent_height <<< "$info"

  [[ $floating == auto_off || $floating == user_off ]] || return 0
  (( siblings > 1 )) || return 0

  case $layout in
    splith)
      target=$(( parent_width * minor_thousandths / 1000 ))
      swaymsg -q "[con_id=$id] resize set width ${target}px"
      ;;
    splitv)
      target=$(( parent_height * minor_thousandths / 1000 ))
      swaymsg -q "[con_id=$id] resize set height ${target}px"
      ;;
  esac
}

cleanup() {
  [[ -n ${subscriber_pid:-} ]] && kill "$subscriber_pid" 2>/dev/null || true
}
trap cleanup EXIT
trap 'exit 0' INT TERM

# Base the first split on the proportions of the currently focused container.
focused_id=$(swaymsg -r -t get_tree | jq -r '.. | objects | select(.focused? == true) | .id' | head -n 1)
[[ -n $focused_id ]] && orient_container "$focused_id"

coproc SWAY_EVENTS { exec swaymsg -m -t subscribe '["window"]'; }
subscriber_pid=$SWAY_EVENTS_PID

while IFS= read -r -u "${SWAY_EVENTS[0]}" event; do
  change=$(jq -r '.change // empty' <<< "$event")
  id=$(jq -r '.container.id // empty' <<< "$event")
  [[ $id =~ ^[0-9]+$ ]] || continue

  case $change in
    new)
      resize_new_container "$id"
      orient_container "$id"
      ;;
    focus)
      orient_container "$id"
      ;;
  esac
done
