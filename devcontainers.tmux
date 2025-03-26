#! /usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "$CURRENT_DIR/scripts/helpers.sh"

update_tmux_devcontainers() {
  local option="$1"
  local option_value="$(get_tmux_option "$option")"
  local new_option_value="FOOBAR" #"$(do_interpolation "$option_value")"
  set_tmux_option "$option" "$new_option_value"
}

main() {
  update_tmux_devcontainers "status-right"
  update_tmux_devcontainers "status-left"
}

main
