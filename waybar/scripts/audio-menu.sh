#!/usr/bin/env bash

set -u

readonly menu_width=500
readonly menu_height=380
readonly select_output='󰓃  Select output device'
readonly select_input='  Select input device'
readonly volume_up='  Increase volume'
readonly volume_down='  Decrease volume'
readonly mute_output='󰖁  Toggle output mute'
readonly mute_input='󰍭  Toggle microphone mute'

notify() {
  local urgency=$1
  local message=$2

  if command -v notify-send >/dev/null 2>&1; then
    notify-send --urgency="$urgency" 'Audio' "$message"
  else
    printf 'Audio: %s\n' "$message" >&2
  fi
}

load_nodes() {
  local type=$1
  local kind=$2
  local icon=$3
  local default_name=$4
  local target_name=$5
  local index name node_description port port_description availability
  local active_port description entry state
  local -n target=$target_name

  while IFS=$'\t' read -r index name node_description port \
      port_description availability active_port; do
    [[ -n $index && -n $name ]] || continue
    state=''
    description=$node_description

    if [[ $port != __none__ ]]; then
      description=$port_description
      [[ $port_description == "$node_description" ]] ||
        description+=" · $node_description"
      if [[ $availability == 'not available' ]]; then
        state=' (not detected)'
      fi
    fi
    if [[ $name == "$default_name" &&
          ($port == __none__ || $port == "$active_port") ]]; then
      state=' (active)'
    fi

    entry="$icon  $kind$state · $description  [$index]"
    target+=("$entry")
    node_names["$entry"]=$name
    node_ports["$entry"]=$port
    node_descriptions["$entry"]=$description
  done < <(
    LC_ALL=C pactl --format=json list "$type" 2>/dev/null |
      jq -r --arg type "$type" '
        .[]
        | select($type != "sources"
            or .monitor_source == null or .monitor_source == "")
        | . as $node
        | if (($node.ports // []) | length) > 0 then
            $node.ports[]
            | [$node.index, $node.name, ($node.description // $node.name),
               .name, (.description // .name),
               (.availability // "unknown"),
               ($node.active_port // "__none__")]
          else
            [$node.index, $node.name, ($node.description // $node.name),
             "__none__", "__none__", "unknown", "__none__"]
          end
        | @tsv
      '
  )
}

choose_node() {
  local kind=$1
  local target_name=$2
  local -n target=$target_name
  local choice name port description stream_type stream_command port_command
  local stream_id

  ((${#target[@]} > 0)) || {
    notify critical "No $kind devices are available."
    return 1
  }

  choice=$(printf '%s\n' "${target[@]}" |
    wofi --dmenu --prompt "Audio $kind" --insensitive \
      --width "$menu_width" --height "$menu_height") || return 0
  [[ -n $choice ]] || return 0
  [[ -n ${node_names[$choice]+x} ]] || return 0

  name=${node_names[$choice]}
  port=${node_ports[$choice]}
  description=${node_descriptions[$choice]}
  if [[ $kind == Output ]]; then
    pactl set-default-sink "$name" || {
      notify critical "Unable to select $description."
      return 1
    }
    port_command=set-sink-port
    stream_type=sink-inputs
    stream_command=move-sink-input
  else
    pactl set-default-source "$name" || {
      notify critical "Unable to select $description."
      return 1
    }
    port_command=set-source-port
    stream_type=source-outputs
    stream_command=move-source-output
  fi

  if [[ $port != __none__ ]] && ! pactl "$port_command" "$name" "$port"; then
    notify critical "Unable to activate $description."
    return 1
  fi

  # Changing the default only affects new streams. Move existing streams too.
  while IFS=$'\t' read -r stream_id _; do
    [[ -n $stream_id ]] || continue
    pactl "$stream_command" "$stream_id" "$name" >/dev/null 2>&1 || true
  done < <(LC_ALL=C pactl list short "$stream_type" 2>/dev/null)

  notify normal "$description is now the default ${kind,,} device."
}

for command in jq pactl wpctl wofi; do
  command -v "$command" >/dev/null 2>&1 || {
    notify critical "$command is not installed."
    exit 1
  }
done

volume_status=$(LC_ALL=C wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || true)
volume=$(printf '%s\n' "$volume_status" |
  awk 'NF >= 2 { printf "%.0f", $2 * 100 }')
[[ -n $volume ]] || volume='--'

default_output=$(LC_ALL=C pactl get-default-sink 2>/dev/null || true)
default_input=$(LC_ALL=C pactl get-default-source 2>/dev/null || true)
declare -A node_names=() node_ports=() node_descriptions=()
output_entries=()
input_entries=()
load_nodes sinks Output '󰓃' "$default_output" output_entries
load_nodes sources Input '' "$default_input" input_entries

entries=(
  "$select_output"
  "$select_input"
  "$volume_up"
  "$volume_down"
  "$mute_output"
  "$mute_input"
)
choice=$(printf '%s\n' "${entries[@]}" |
  wofi --dmenu --prompt "Audio · ${volume}%" --insensitive \
    --width "$menu_width" --height "$menu_height") || exit 0

case $choice in
  "$select_output") choose_node Output output_entries ;;
  "$select_input") choose_node Input input_entries ;;
  "$volume_up") wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+ ;;
  "$volume_down") wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- ;;
  "$mute_output") wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle ;;
  "$mute_input") wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle ;;
esac
