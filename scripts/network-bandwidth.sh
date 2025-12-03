#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/helpers.sh"


get_bandwidth_for_osx() {
  local x=$(get_tmux_option "@tmux-network-interface-regex" '^(eth|en|wl)')
  netstat -ibn |
  awk -v t=$(date +%s%N) -v x="$x" 'NR>1 {if( $1~x && !seen[$1]++ ){ i+=$(NF-4); o+=$(NF-1) }} END {print i,o, substr(t,1,length(t)-3)}'
}

get_bandwidth_for_linux() {
  local x=$(get_tmux_option "@tmux-network-interface-regex" '^(eth|en|wl)')
  awk -v t=${EPOCHREALTIME/./} -v x="$x" 'NR>2 {if( $1~x ){ i+=$2; o+=$10 }} END {print i,o,t}' /proc/net/dev
}

get_bandwidth() {
  local os="$1"

  case $os in
    osx)
      echo -n $(get_bandwidth_for_osx)
      return 0
      ;;
    linux)
      echo -n $(get_bandwidth_for_linux)
      return 0
      ;;
    *)
      echo -n "0 0"
      return 1
      ;;
  esac
}

format_speed() {
  local padding=$(get_tmux_option "@tmux-network-bandwidth-padding" 5)
  numfmt --to=iec --suffix "B/s" --format "%f" --padding $padding $1
}

main() {
  local os=$(os_type)
  local old_data=( $(get_tmux_option "@network-bandwidth-previous-data") )
  if [ -z "$old_data" ]; then
    old_data=( $(get_bandwidth $os) )
    set_tmux_option "@network-bandwidth-previous-data" "${old_data[*]}"
    exit 0
  fi

  local new_data=( $(get_bandwidth $os) )
  set_tmux_option "@network-bandwidth-previous-data" "${new_data[*]}"
  local elapsed=$((${new_data[2]} - ${old_data[2]}))
  local download_speed=$(((${new_data[0]} - ${old_data[0]}) * 1000000 / $elapsed))
  local upload_speed=$(((${new_data[1]} - ${old_data[1]}) * 1000000 / $elapsed))

  echo -n "↓$(format_speed $download_speed) ↑$(format_speed $upload_speed)"
}

main
