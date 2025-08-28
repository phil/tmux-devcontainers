#! /usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$CURRENT_DIR/../helpers.sh"

#####################################################################
#
# Globals
#
#####################################################################
CURRENT_PANE_PATH=$(tmux display-message -p -F "#{pane_current_path}")
JSON_FILE="${CURRENT_PANE_PATH}/.devcontainer/devcontainer.json"
BASE_COMMAND="docker compose"

#####################################################################
#
# get_project_name
#
# Try to get the project name for devcontainers with or whithout
# docker compose
#
#####################################################################
get_project_name() {
    # local -r compose_file="$1"
    # local project_name=""

    # if [[ -n "${COMPOSE_PROJECT_NAME}" ]]; then
    #     project_name=${COMPOSE_PROJECT_NAME}
    # elif [[ -z "${compose_file}" ]]; then
    #     project_name=$(devcontainer read-configuration --workspace-folder "${CURRENT_PANE_PATH}" 2>/dev/null | jq -r '.configuration.name')
    # fi

    # if [[ -z "${project_name}" ]] || [[ "${project_name}" == "null" ]]; then
    #     if [[ -n "${compose_file}" ]]; then
    #         project_name="${CURRENT_PANE_PATH##*/}_devcontainer"
    #     else
    #         project_name="${CURRENT_PANE_PATH##*/}"
    #     fi
    # fi

    # local project_name=$(get_devcontainer_config ".configuration.name")
    local devcontainer_config="$1"
    local project_name=$(echo "$devcontainer_config" | jq -r ".name // \"\"")
    echo "${project_name}"
}

#####################################################################
#
# get_compose_config
#
# Try to get the the docker compose file
#
#####################################################################
# get_compose_config() {
#     local compose_files=""
#     local compose_files_fp=""

#     if [[ -n "$(grep -i -e 'dockerComposeFile": \[' ${JSON_FILE})" ]]; then
#         compose_files=$(grep -v "//" ${JSON_FILE} | jq -r '.dockerComposeFile |= join(" ") | .dockerComposeFile')
#     else
#         compose_files=$(grep -i -e 'dockerComposeFile' \"${JSON_FILE}\")
#         compose_files=$(tmp=${compose_file##* }; tmp=${tmp//\"/}; echo "${tmp/,/}")
#     fi

#     if [[ -n "${compose_files}" ]]; then
#         for compose_file in ${compose_files}
#         do
#             compose_files_fp="${compose_files_fp} ${CURRENT_PANE_PATH}/.devcontainer/${compose_file}"
#         done
#     fi

#     echo "${compose_files_fp}"
# }
get_docker_compose_files() {
    local devcontainer_config="$1"
    # local compose_files=$(get_devcontainer_config ".configuration.dockerComposeFile | .[]")
    local compose_files=$(echo "$devcontainer_config" | jq -r ".dockerComposeFile | .[]")
    local workspace_dir=$(get_workspace_dir)
    local compose_files_fp=""

    debug "compose_files: $compose_files"

    if [[ -n "${compose_files}" ]]; then
        for compose_file in ${compose_files}
        do
            debug "compose_file: $compose_file"
            compose_files_fp="${compose_files_fp} ${workspace_dir}/.devcontainer/${compose_file}"
        done
    fi

    echo "${compose_files_fp}"
}

#####################################################################
#
# get_docker_config
#
# Try to get the the Dockerfile
#
#####################################################################
get_docker_config() {
    local docker_file=""
    docker_file=$(grep -i -e 'dockerFile' "${JSON_FILE}")
    docker_file=$(tmp=${docker_file##* }; tmp=${tmp//\"/}; echo "${tmp/,/}")

    if [[ -n "${docker_file}" ]]; then
        docker_file="${CURRENT_PANE_PATH}/.devcontainer/${compose_file}"
    fi

    echo "${docker_file}"
}

#####################################################################
#
# compose_status
#
# return devcontainer status when using docker compose
#
#####################################################################
compose_status() {
    local -r compose_files="$1"
    local -r project_name="$2"
    local docker_status=""
    local docker_command=${BASE_COMMAND}

    if [[ -n "${project_name}" ]]; then
        docker_command="${docker_command} -p ${project_name}"
    fi

    docker_status=""
    for compose_file in ${compose_files}
    do
        docker_status_tmp=$(${docker_command} -f "${compose_file}" ps --all --format json | jq -r '. | "\(.Service):\(.State)"')
        
        if [[ -z "${docker_status_tmp}" ]]; then
            services=$(${docker_command} -f "${compose_file}" config --services)
            for service in ${services}
            do
                image=$(docker images -q --filter reference="*${project_name//-/*}*${service}*:*")
                if [[ -n "${image}" ]]; then
                    image_status="built"
                else
                    image_status="unknown"
                fi
                if [[ "${docker_status}" != *${service}* ]]; then
                    docker_status="${docker_status} ${service}: ${image_status}"
                fi
            done
        else
            docker_status="${docker_status_tmp}"
        fi
    done

    echo "${docker_status}"
}

status_from_docker_compose() {
    local devcontainer_config="$1"
    local status=""

    local composefiles=$(get_docker_compose_files "$devcontainer_config")

    # using the config dockerComposeFile, we can use these paths with docker compose to return a list of services
    # loop over each service to get the status
    #
    # append to the status variable

    local workspace_dir=$(get_workspace_dir)
    local args=""

    for compose_file in ${composefiles}
    do
        args="${args} -f ${compose_file}"
    done

    debug "ARGS: $args"

    docker_compose_config=$(docker compose $args config --format json 2>/dev/null)
    debug "CONFIG: $docker_compose_config"

    echo "$docker_compose_config" | jq -r '.services | keys[] as $k | "\($k):\(.[$k].image // "no image")"' | xargs

    # echo "${status}"
}

#####################################################################
#
# plain_status
#
# return devcontainer status when using a Dockerfile or none
#
#####################################################################
status_from_docker_file() {
    local -r project_name="$1"
    local docker_status=""

    status=$(docker ps -a --format json | jq -r ". | select(.Names | contains(\"${project_name}\")) | .State")
    if [[ -z "${status}" ]]; then
        status=$(docker ps -all --format json | jq -r ". | select(.Image | contains(\"${project_name}\")) | .State")
    fi

    if [[ -n "${status}" ]]; then
        docker_status="${project_name}: ${status} (plain)"
    else
        image=$(docker images -a | grep -E ".*(${CURRENT_PANE_PATH##*/}|${project_name//-/*}).*")
        if [[ -n "${image}" ]]; then
            docker_status="${project_name}: built (plain)"
        else
            docker_status="${project_name}: unkown (plain)"
        fi
    fi

    echo "${docker_status}"
}

status_from_image() {
    echo "IMAGE STATUS"
}


detect_orchestration() {
    local devcontainer_config="$1"
    local orchestrator=""

    # debug "devcontainer config: $devcontainer_config"

    # debug "dockerComposeFile: $(echo $devcontainer_config | jq -r ".dockerComposeFile // \"\"")"
    # debug "dockerFile: $(echo $devcontainer_config | jq -r ".dockerFile // \"\"")"
    # debug "image: $(echo $devcontainer_config | jq -r ".image // \"\"")"

    if [[ -n $(echo $devcontainer_config | jq -r ".dockerComposeFile // \"\"") ]]; then
        orchestrator="compose"
    elif [[ -n $(echo $devcontainer_config | jq -r ".dockerFile // \"\"") ]]; then
        orchestrator="docker"
    elif [[ -n $(echo $devcontainer_config | jq -r ".image // \"\"") ]]; then
        orchestrator="image"
    else
        orchestrator="none"
    fi

    echo "${orchestrator}"
}

#####################################################################
#
# Main code
#
#####################################################################
if [[ -d $(get_workspace_dir) ]]; then
    devcontainer_config=$(get_devcontainer_config ".configuration")
    # compose_files=$(get_compose_config)
    # docker_file=$(get_docker_config)
    # project_name=$(get_project_name "${compose_file}")

    project_name=$(get_project_name "$devcontainer_config")
    orchestration=$(detect_orchestration "$devcontainer_config")

    case ${orchestration} in
        "compose")
            docker_status=$(status_from_docker_compose "$devcontainer_config")
            ;;
        "docker")
            docker_status=$(status_from_docker_file "${project_name}")
            ;;
        "image")
            docker_status=$(status_from_image)
            ;;
        *)
            docker_status="Devcontainer Parse Error"
            ;;
    esac

    # shellcheck disable=SC2086
    echo "**${orchestration}** ${docker_status}"
else
    # Workspace does not have devcontainers
    echo "N/A"
fi
