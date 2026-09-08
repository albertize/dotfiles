#!/usr/bin/env bash

# Sway autotiling: split each selected container into equal halves. Splits
# alternate horizontally and vertically, starting horizontally.
set -uo pipefail

command -v jq >/dev/null 2>&1 || {
  printf 'golden-layout: jq is not installed\n' >&2
  exit 1
}

container_info() {
  local id=$1

  swaymsg -r -t get_tree | jq -r --argjson id "$id" '
    def locate($wanted; $workspace):
      . as $parent
      | ((.nodes // []) + (.floating_nodes // []))[] as $child
      | ($child | if .type == "workspace" then . else $workspace end) as $child_workspace
      | if $child.id == $wanted then
          {parent: $parent, node: $child, workspace: $child_workspace}
        else
          ($child | locate($wanted; $child_workspace))
        end;

    locate($id; null)
    | [
        .parent.layout,
        (.parent.nodes | length),
        .node.floating,
        .parent.rect.width,
        .parent.rect.height,
        (.workspace | [recurse(.nodes[]?) | select(.pid? != null)] | length)
      ]
    | @tsv
  ' | head -n 1
}

orient_container() {
  local id=$1
  local info layout siblings floating parent_width parent_height tiled_count

  info=$(container_info "$id")
  [[ -n $info ]] || return 0
  IFS=$'\t' read -r layout siblings floating parent_width parent_height tiled_count <<< "$info"

  # Floating windows do not participate in automatic layout.
  [[ $floating == auto_off || $floating == user_off ]] || return 0
  [[ $tiled_count =~ ^[0-9]+$ ]] || return 0

  if (( tiled_count % 2 == 1 )); then
    swaymsg -q "[con_id=$id] split h"
  else
    swaymsg -q "[con_id=$id] split v"
  fi
}

balance_new_container() {
  local id=$1
  local info layout siblings floating parent_width parent_height tiled_count target

  info=$(container_info "$id")
  [[ -n $info ]] || return 0
  IFS=$'\t' read -r layout siblings floating parent_width parent_height tiled_count <<< "$info"

  [[ $floating == auto_off || $floating == user_off ]] || return 0
  (( siblings == 2 )) || return 0

  case $layout in
    splith)
      target=$(( parent_width / 2 ))
      swaymsg -q "[con_id=$id] resize set width ${target}px"
      ;;
    splitv)
      target=$(( parent_height / 2 ))
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
      balance_new_container "$id"
      orient_container "$id"
      ;;
    focus)
      orient_container "$id"
      ;;
  esac
done
