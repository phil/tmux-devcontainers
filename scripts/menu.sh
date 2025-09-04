#! /usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "$CURRENT_DIR/helpers.sh"

show_menu() {
    show_active_menu
}

show_active_menu() {
    local project_name=$(get_devcontainer_config ".configuration.name")

    tmux display-menu -T " Devcontainers " \
        "" \
        "-Workspace: #[fg=white]${project_name}" "" "" \
        "" \
        "Up"                    u "run -b 'source $CURRENT_DIR/commands.sh && run_up'" \
        "Down"                  d "run -b 'source $CURRENT_DIR/commands.sh && run_down'" \
        "Purge"                 p "run -b 'source $CURRENT_DIR/commands.sh && run_purge'" \
        "ReBuild"               r "run -b 'source $CURRENT_DIR/commands.sh && run_rebuild'" \
        "Exec in popup"         e "run -b 'source $CURRENT_DIR/commands.sh && run_exec_in_popup'" \
        "Exec in new window"    E "run -b 'source $CURRENT_DIR/commands.sh && run_exec_in_window'" \
        "" \
        "-All commands work with the devcontainers cli," "" "" \
        "-except commands specified with 'docker compose'" "" "" \
        "-Exec commands assume bash is available in the container" "" ""
}
