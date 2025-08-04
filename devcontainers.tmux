#! /usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "$CURRENT_DIR/scripts/helpers.sh"

devcontainers_interpolations=(
    "\#{devcontainers_status}"
)

devcontainers_commands=(
    "#($CURRENT_DIR/scripts/status.sh)"
)

# Usage
# # interpolate_tmux_option <option>
interpolate_tmux_option() {
    local option=$1
    local option_value=$(get_tmux_option "$option")

    for ((i = 0; i < ${#devcontainers_commands[@]}; i++)); do
      option_value=${option_value/${devcontainers_interpolations[$i]}/${devcontainers_commands[$i]}}
    done

    set_tmux_option "$option" "$option_value"
}


main() {
    interpolate_tmux_option "status-right"
    interpolate_tmux_option "status-left"

    tmux bind-key $(get_tmux_option "@devcontainers_exec_key" E) "new-window 'devcontainer exec --workspace-folder . /bin/bash'"

    tmux bind-key $(get_tmux_option "@devcontainers_menu_key" C-e) run -b "source $CURRENT_DIR/scripts/menu.sh && show_menu"
}

main
