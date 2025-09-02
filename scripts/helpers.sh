debug() {
    echo "$1" >&2
}


# Get Tmux option value, if not set, use default value
# checks for local, then global options
#
# Usage
# get_tmux_option <option> <default_value>
get_tmux_option() {
    local option="$1"
    local default_value="$2"
    local option_value=$(tmux show-option -qv "$option")

    if [ -z "$option_value" ]; then
        option_value=$(tmux show-option -gqv "$option")
    fi

    if [ -z "$option_value" ]; then
        echo "$default_value"
    else
        echo "$option_value"
    fi
}

# Set Tmux option value
#
# Usage
# set_tmux_option <option> <value>
set_tmux_option() {
    local option=$1
    local value=$2
    tmux set-option -gq "$option" "$value"
}

# Get the current pane's path
get_current_pane_path() {
    local current_pane_path=$(tmux display-message -p -F "#{pane_current_path}")
    echo "$current_pane_path"
}

# Get the workspace directory from the current pane's path
# This function will check parent directories for a .devcontainer directory, 
# and return the path to the workspace directory.
get_workspace_dir() {
    local current_dir="$(get_current_pane_path)"
    
    current_dir=$(realpath "$current_dir")
    
    while [[ "$current_dir" != "/" ]]; do
        if [[ -d "$current_dir/.devcontainer" ]]; then
            break
        fi
        current_dir=$(dirname "$current_dir")
    done

    if [[ "$current_dir" == "/" ]]; then
        echo ""
    else 
        echo "$current_dir"
    fi
}

# Get devcontainer configuration value from the current pane's devcontainer.json
# expects the key_path to be a valid jq path
#
# Usage
# get_devcontainer_config <key_path> <default_value>
# Example: get_devcontainer_config ".configuration.name"
# Example: get_devcontainer_config ".configuration.name" "app-server"
get_devcontainer_config() {
    # debug "Getting devcontainer config for key path: $1 with default value: $2"
    local key_path="$1"
    local default_value="$2"

    # TODO: Memoize this function to avoid multiple calls to devcontainer read-configuration?
    local json=$(devcontainer read-configuration --workspace-folder "$(get_workspace_dir)" 2>/dev/null)

    local value=$(echo "$json" | jq -r "${key_path} // \"\"")


    if [ ! -z "$value" ]; then
        echo "$value"
    else
        echo "$default_value"
    fi
}

check_workspace() {
    if [[ -z $(get_workspace_dir) ]]; then
        tmux display-message "No devcontainer found in the current workspace"
        exit 0
    fi
}

get_exec_command() {
    exec_command=$(get_devcontainer_config ".configuration.customizations.tmux.execCommand" "/bin/bash")
    echo "$exec_command"
}
