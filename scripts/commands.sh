#! /usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$CURRENT_DIR/helpers.sh"

######################################################################
# up
######################################################################

run_up() {
    check_workspace
    local command=$(up_command)
    tmux new-window -n "devcontainer_build" -c "$(get_workspace_dir)" "tmux set-option remain-on-exit failed; ${command} && tmux refresh-client -S"
}

test_up() {
    local command=$(up_command)
    eval "$command"
}

up_command() {
    echo "devcontainer up --workspace-folder $(get_workspace_dir)"
}

######################################################################
# down
######################################################################

run_down() {
    check_workspace
    local workspace_dir=$(get_workspace_dir)
    local devcontainer_config=$(get_devcontainer_config ".configuration")

    local command=$(down_command "$devcontainer_config")
    tmux new-window -n "devcontainer_down" -c "$workspace_dir" "tmux set-option remain-on-exit failed; ${command} && tmux refresh-client -S"
}

test_down() {
    debug "Running Down"
    local devcontainer_config=$(get_devcontainer_config ".configuration")
    local command=$(down_command "$devcontainer_config")
    eval "$command"
}

down_command() {
    local devcontainer_config=$1
    local workspace_dir=$(get_workspace_dir)

    case $(detect_orchestration "$devcontainer_config") in
        "compose")
            local compose_files=($(get_docker_compose_files "$devcontainer_config"))
            local docker_compose_command="docker compose"

            for compose_file in ${compose_files[*]}
            do
                docker_compose_command="${docker_compose_command} -f ${compose_file}"
            done

            echo "${docker_compose_command} stop";;

        "docker" | "image")
            local container_id=$(docker ps -q --filter "status=running" --filter "label=devcontainer.local_folder=$workspace_dir")
            if [ -n "$container_id" ]; then
                echo "docker stop $container_id"
            fi ;;
    esac

}

######################################################################
# purge
######################################################################

run_purge() {
    check_workspace
    run_down

    local workspace_dir=$(get_workspace_dir)
    local devcontainer_config=$(get_devcontainer_config ".configuration")
    local command=$(purge_command "$devcontainer_config")

    tmux new-window -n "devcontainer_down" -c "$workspace_dir" "tmux set-option remain-on-exit failed; ${purge_command} && tmux refresh-client -S"
}

test_purge() {
    debug "Running Purge"

    test_down

    local devcontainer_config=$(get_devcontainer_config ".configuration")
    local command=$(purge_command "$devcontainer_config")

    eval "$command"
}

purge_command() {
    local devcontainer_config="$1"
    local workspace_dir=$(get_workspace_dir)

    case $(detect_orchestration "$devcontainer_config") in
        "compose")
            local compose_files=($(get_docker_compose_files "$devcontainer_config"))
            local docker_compose_command="docker compose"

            for compose_file in ${compose_files[*]}
            do
                docker_compose_command="${docker_compose_command} -f ${compose_file}"
            done

            echo "$docker_compose_command down --rmi local --volumes";;

        "docker" | "image")
            local container_id=$(docker ps -q --filter "status=exited" --filter "label=devcontainer.local_folder=$workspace_dir")
            if [ -n "$container_id" ]; then
                echo "docker rm $container_id"
            fi ;;
    esac
}



run_rebuild() {
    check_workspace
    run_purge
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

