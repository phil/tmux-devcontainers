#! /usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$CURRENT_DIR/../helpers.sh"

#####################################################################
#
# get_project_name
#
# Try to get the project name for devcontainers with or whithout
# docker compose
#
#####################################################################
get_project_name() {
    local devcontainer_config="$1"
    local project_name=$(echo "$devcontainer_config" | jq -r '.name // ""')
    echo "${project_name}"
}

#####################################################################
#
# get_docker_compose_files
#
# Try to get the the docker compose files from the devcontainer config
# and return their full path
#
#####################################################################
get_docker_compose_files() {
    local devcontainer_config="$1"
    local compose_files=$(echo "$devcontainer_config" | jq -r ".dockerComposeFile | arrays // [.] | .[]")
    local workspace_dir=$(get_workspace_dir)
    local compose_files_full_path=""

    for compose_file in ${compose_files}
    do
        compose_files_full_path="${compose_files_full_path} ${workspace_dir}/.devcontainer/${compose_file}"
    done

    echo "${compose_files_full_path}"
}

#####################################################################
# status_from_docker_compose
# return devcontainer status when using docker compose
# This function handles multiple compose files and merges their status
# into a single output
#####################################################################
status_from_docker_compose() {
    local devcontainer_config="$1"
    local workspace_dir=$(get_workspace_dir)
    local compose_files=($(get_docker_compose_files "$devcontainer_config"))

    # setup docker compose command with all compose files
    local docker_compose_command="docker compose"
    for compose_file in ${compose_files}
    do
        docker_compose_command="${docker_compose_command} -f ${compose_file}"
    done

    local docker_compose_status=$(${docker_compose_command} ps --all --format json | jq -r '. | "\(.Service):\(.State)"')

    # Check to see if the docker compose command returned any status
    # if not, we need to check if the services are built or not
    # and return the status accordingly
    if [[ -z "${docker_compose_status}" ]]; then
        services=$(${docker_compose_command} config --format json | jq -r '.services | keys[]')
        for service in ${services}
        do
            image=$(docker images -q --filter reference="*${project_name//-/*}*${service}*:*")
            if [[ -n "${image}" ]]; then
                image_status="built"
            else
                image_status="unknown"
            fi
            if [[ "${docker_compose_status}" != *${service}* ]]; then
                docker_compose_status="${docker_compose_status} ${service}:${image_status}"
            fi
        done
    fi

    echo "${docker_compose_status}" | xargs
}

#####################################################################
# status_from_docker_file
# return devcontainer status when using a Dockerfile
#####################################################################
status_from_docker_file() {
    local devcontainer_config="$1"
    local workspace_dir=$(get_workspace_dir)

    local container_config=$(docker ps -a --format json | jq -r ". | select((.Labels | contains(\"$workspace_dir\"))) | .")
    local container_status=$(echo "$container_config" | jq -r '.State // ""')

    echo "Dockerfile:${container_status:-unknown}"
}

#####################################################################
# status_from_image
# return devcontainer status when using an image
#####################################################################
status_from_image() {
    local devcontainer_config="$1"
    local workspace_dir=$(get_workspace_dir)

    local image_name=$(echo "$devcontainer_config" | jq -r '.image // ""')
    local image_short_name=${image_name##*/}

    local container_config=$(docker ps -a --format json | jq -r ". | select((.Image == \"$image_name\") and (.Labels | contains(\"$workspace_dir\"))) | .")
    local container_status=$(echo "$container_config" | jq -r '.State // ""')

    echo "$image_short_name:${container_status:-unknown}"
}

#####################################################################
# detect_orchestration
# Detect which orchestration method is used in the devcontainer
#####################################################################
detect_orchestration() {
    local devcontainer_config="$1"
    local orchestrator=""

    if [[ -n $(echo $devcontainer_config | jq -r '.dockerComposeFile // ""') ]]; then
        orchestrator="compose"
    elif [[ -n $(echo $devcontainer_config | jq -r '.dockerFile // ""') ]]; then
        orchestrator="docker"
    elif [[ -n $(echo $devcontainer_config | jq -r '.image // ""') ]]; then
        orchestrator="image"
    else
        orchestrator="none"
    fi

    echo "${orchestrator}"
}

#####################################################################
# Main code
#####################################################################
if [[ -d $(get_workspace_dir) ]]; then
    devcontainer_config=$(get_devcontainer_config ".configuration")
    project_name=$(get_project_name "$devcontainer_config")
    orchestration=$(detect_orchestration "$devcontainer_config")

    case ${orchestration} in
        "compose")
            docker_status=$(status_from_docker_compose "${devcontainer_config}")
            ;;
        "docker")
            docker_status=$(status_from_docker_file "${devcontainer_config}")
            ;;
        "image")
            docker_status=$(status_from_image "${devcontainer_config}")
            ;;
        *)
            docker_status="Devcontainer:Error"
            ;;
    esac

    echo "${docker_status}"
fi
