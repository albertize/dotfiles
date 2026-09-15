#!/usr/bin/env bash

set -u

readonly menu_width=500
readonly menu_height=380
readonly select_output='󰓃  Select output device'
readonly select_input='  Select input device'
readonly select_profile='󰕾  Select audio profile'
readonly manage_streams='󰎈  Manage application streams'
readonly volume_up='  Increase volume'
readonly volume_down='  Decrease volume'
readonly mute_output='󰖁  Toggle output mute'
readonly mute_input='󰍭  Toggle microphone mute'
readonly move_stream='󰓡  Move to another device'
readonly stream_volume_up='  Increase application volume'
readonly stream_volume_down='  Decrease application volume'
readonly stream_mute='󰖁  Toggle application mute'
readonly back='󰁍  Back'

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

load_profiles() {
  local index card card_description profile description active_profile
  local entry state

  while IFS=$'\t' read -r index card card_description profile description \
      active_profile; do
    [[ -n $index && -n $card && -n $profile ]] || continue
    if [[ -z $description || $description == '(null)' ]]; then
      description=${profile//-/ }
      description=${description//:/ }
      description=${description//+/ + }
      description=${description//output/Output}
      description=${description//input/Input}
      description=${description//hdmi/HDMI}
      description=${description//a2dp/A2DP}
      description=${description//hfp/HFP}
      description=${description//hsp/HSP}
      description=${description//surround71/7.1 surround}
    fi
    state=''
    [[ $profile == "$active_profile" ]] && state=' (active)'
    entry="󰕾  Profile$state · $description · $card_description  [$index]"
    profile_entries+=("$entry")
    profile_cards["$entry"]=$card
    profile_names["$entry"]=$profile
    profile_descriptions["$entry"]=$description
  done < <(
    LC_ALL=C pactl --format=json list cards 2>/dev/null |
      jq -r '
        .[]
        | . as $card
        | $card.profiles
        | to_entries[]
        | select(.value.available != false)
        | [$card.index, $card.name,
           ($card.properties["device.description"] // $card.name),
           .key, (.value.description // .key), $card.active_profile]
        | @tsv
      '
  )
}

choose_profile() {
  local choice card profile description

  ((${#profile_entries[@]} > 0)) || {
    notify critical 'No audio profiles are available.'
    return 1
  }

  choice=$(printf '%s\n' "${profile_entries[@]}" |
    wofi --dmenu --prompt 'Audio profile' --insensitive \
      --width "$menu_width" --height "$menu_height") || return 0
  [[ -n $choice ]] || return 0
  [[ -n ${profile_names[$choice]+x} ]] || return 0

  card=${profile_cards[$choice]}
  profile=${profile_names[$choice]}
  description=${profile_descriptions[$choice]}
  if pactl set-card-profile "$card" "$profile"; then
    notify normal "$description is now the active audio profile."
  else
    notify critical "Unable to activate $description."
    return 1
  fi
}

load_streams() {
  local type=$1
  local kind=$2
  local icon=$3
  local index app media entry

  while IFS=$'\t' read -r index app media; do
    [[ -n $index ]] || continue
    [[ -n $app ]] || app='Unknown application'
    [[ -n $media ]] || media=$kind
    entry="$icon  $kind · $app · $media  [$index]"
    stream_entries+=("$entry")
    stream_ids["$entry"]=$index
    stream_kinds["$entry"]=$kind
    stream_descriptions["$entry"]="$app · $media"
  done < <(
    LC_ALL=C pactl --format=json list "$type" 2>/dev/null |
      jq -r '
        .[]
        | [.index, (.properties["application.name"] // ""),
           (.properties["media.name"] // "")]
        | @tsv
      '
  )
}

move_application_stream() {
  local stream_id=$1
  local kind=$2
  local target_name choice name port description port_command move_command
  local -n targets=$3

  ((${#targets[@]} > 0)) || {
    notify critical "No $kind devices are available."
    return 1
  }
  choice=$(printf '%s\n' "${targets[@]}" |
    wofi --dmenu --prompt "Move stream to ${kind,,}" --insensitive \
      --width "$menu_width" --height "$menu_height") || return 0
  [[ -n $choice ]] || return 0
  [[ -n ${node_names[$choice]+x} ]] || return 0

  name=${node_names[$choice]}
  port=${node_ports[$choice]}
  description=${node_descriptions[$choice]}
  if [[ $kind == Output ]]; then
    port_command=set-sink-port
    move_command=move-sink-input
  else
    port_command=set-source-port
    move_command=move-source-output
  fi
  if [[ $port != __none__ ]] && ! pactl "$port_command" "$name" "$port"; then
    notify critical "Unable to activate $description."
    return 1
  fi
  if pactl "$move_command" "$stream_id" "$name"; then
    notify normal "Application stream moved to $description."
  else
    notify critical "Unable to move the application stream to $description."
    return 1
  fi
}

manage_application_streams() {
  local choice stream_id kind description action object volume_command

  ((${#stream_entries[@]} > 0)) || {
    notify normal 'No application audio streams are active.'
    return 0
  }
  choice=$(printf '%s\n' "${stream_entries[@]}" |
    wofi --dmenu --prompt 'Application audio streams' --insensitive \
      --width "$menu_width" --height "$menu_height") || return 0
  [[ -n $choice ]] || return 0
  [[ -n ${stream_ids[$choice]+x} ]] || return 0

  stream_id=${stream_ids[$choice]}
  kind=${stream_kinds[$choice]}
  description=${stream_descriptions[$choice]}
  if [[ $kind == Playback ]]; then
    object=sink-input
  else
    object=source-output
  fi

  action=$(printf '%s\n' "$move_stream" "$stream_volume_up" \
    "$stream_volume_down" "$stream_mute" "$back" |
    wofi --dmenu --prompt "$description" --insensitive \
      --width "$menu_width" --height 205) || return 0
  case $action in
    "$move_stream")
      if [[ $kind == Playback ]]; then
        move_application_stream "$stream_id" Output output_entries
      else
        move_application_stream "$stream_id" Input input_entries
      fi
      ;;
    "$stream_volume_up") volume_command=+5%; pactl "set-$object-volume" "$stream_id" "$volume_command" ;;
    "$stream_volume_down") volume_command=-5%; pactl "set-$object-volume" "$stream_id" "$volume_command" ;;
    "$stream_mute") pactl "set-$object-mute" "$stream_id" toggle ;;
  esac
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
declare -A profile_cards=() profile_names=() profile_descriptions=()
declare -A stream_ids=() stream_kinds=() stream_descriptions=()
output_entries=()
input_entries=()
profile_entries=()
stream_entries=()
load_nodes sinks Output '󰓃' "$default_output" output_entries
load_nodes sources Input '' "$default_input" input_entries
load_profiles
load_streams sink-inputs Playback '󰎆'
load_streams source-outputs Recording '󰍬'

entries=(
  "$select_output"
  "$select_input"
  "$select_profile"
  "$manage_streams"
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
  "$select_profile") choose_profile ;;
  "$manage_streams") manage_application_streams ;;
  "$volume_up") wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+ ;;
  "$volume_down") wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- ;;
  "$mute_output") wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle ;;
  "$mute_input") wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle ;;
esac
