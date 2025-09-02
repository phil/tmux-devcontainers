#! /usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "$CURRENT_DIR/helpers.sh"

run_up() {
    check_workspace
    tmux new-window -n "devcontainer_build" -c "$(get_workspace_dir)" "tmux set-option remain-on-exit failed; devcontainer up --workspace-folder . && tmux refresh-client -S"
}

run_down() {
    check_workspace
    tmux new-window -n "devcontainer_down" -c "$(get_workspace_dir)" "tmux set-option remain-on-exit failed; docker compose down && tmux refresh-client -S"
}

run_rebuild() {
    check_workspace
    run_down
    run_up
}

run_exec_in_popup() {
    check_workspace
    tmux display-popup -EE "devcontainer exec --workspace-folder $(get_workspace_dir) $(get_exec_command)"
}

run_exec_in_window() {
    check_workspace
    tmux new-window "devcontainer exec --workspace-folder $(get_workspace_dir) $(get_exec_command)"
}

