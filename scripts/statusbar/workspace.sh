#! /usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "$CURRENT_DIR/../helpers.sh"

if [[ -z $(get_workspace_dir) ]]; then
    echo ""
else
    echo $(get_devcontainer_config ".configuration.name")
fi
