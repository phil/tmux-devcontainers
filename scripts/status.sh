#! /usr/bin/env bash

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
    local -r compose_file="$1"
    local project_name=""
    local devcontainer_name=""

    if [[ -n "${COMPOSE_PROJECT_NAME}" ]]; then
        project_name=${COMPOSE_PROJECT_NAME}
    elif [[ -n "${compose_file}" ]]; then
        project_name="${CURRENT_PANE_PATH##*/}_devcontainer"
    fi

    devcontainer_name=$(devcontainer read-configuration --workspace-folder "${CURRENT_PANE_PATH}" 2>/dev/null | jq -r '.configuration.name')

    if [[ -z "${project_name}" ]] || [[ "${project_name}" == "null" ]]; then
        if [[ -n "${devcontainer_name}" ]] && [[ "${devcontainer_name}" != "null" ]]; then
            project_name="${devcontainer_name}"
        else
            project_name="${CURRENT_PANE_PATH##*/}"
        fi
    fi

    echo "${project_name}"
}

#####################################################################
#
# get_compose_config
#
# Try to get the the docker compose file
#
#####################################################################
get_compose_config() {
    local compose_files=""
    local compose_files_fp=""

    if [[ -n "$(grep -i -e 'dockerComposeFile": \[' ${JSON_FILE})" ]]; then
        compose_files=$(grep -v "//" ${JSON_FILE} | jq -r '.dockerComposeFile |= join(" ") | .dockerComposeFile')
    else
        compose_files=$(grep -i -e 'dockerComposeFile' ${JSON_FILE})
        compose_files=$(tmp=${compose_files##* }; tmp=${tmp//\"/}; echo "${tmp/,/}")
    fi

    if [[ -n "${compose_files}" ]]; then
        for compose_file in ${compose_files}
        do
            compose_files_fp="${compose_files_fp} ${CURRENT_PANE_PATH}/.devcontainer/${compose_file}"
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

#####################################################################
#
# plain_status
#
# return devcontainer status when using a Dockerfile or none
#
#####################################################################
plain_status() {
    local -r project_name="$1"
    local docker_status=""
    set -x

    status=$(docker ps -a --format json | jq -r ". | select(.Names | contains(\"${project_name}\") or contains(\"${CURRENT_PANE_PATH##*/}\")) | .State")
    if [[ -z "${status}" ]]; then
        status=$(docker ps -all --format json | jq -r ". | select(.Image | contains(\"${project_name}\") or contains(\"${CURRENT_PANE_PATH##*/}\")) | .State")
    fi

    if [[ -n "${status}" ]]; then
        docker_status="${project_name}: ${status} "
    else
        image=$(docker images -a | grep -E ".*(${CURRENT_PANE_PATH##*/}|${project_name//-/*}).*")
        if [[ -n "${image}" ]]; then
            docker_status="${project_name}: built"
        else
            docker_status="${project_name}: unkown"
        fi
    fi
    set +x

    echo "${docker_status}"
}

#####################################################################
#
# Main code
#
#####################################################################
if [ -f "${JSON_FILE}" ]; then
    compose_files=$(get_compose_config)
    docker_file=$(get_docker_config)
    project_name=$(get_project_name "${compose_file}")

    if [[ -n "${compose_files}" ]]; then
        docker_status=$(compose_status "${compose_files}" "${project_name}")
    else
        docker_status=$(plain_status "${project_name}")
    fi

    # shellcheck disable=SC2086
    echo ${docker_status}
else
    # Workspace does not have devcontainers
    echo "N/A"
fi
