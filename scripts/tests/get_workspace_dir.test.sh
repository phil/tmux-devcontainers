#!/usr/bin/env bash
#
# Tests for get_workspace_dir (issue #18: infinite loop on invalid paths).
#
# No external test framework is required. Each case runs the function in a
# background subshell and is killed if it exceeds a short timeout, so the
# original hang bug fails loudly instead of hanging the suite.
#
# Usage: bash scripts/tests/get_workspace_dir.test.sh

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS="${SCRIPT_DIR}/../helpers.sh"

# shellcheck source=/dev/null
source "$HELPERS"

TIMEOUT_SECS=5
failures=0

# run_with_timeout <var_for_output> <var_for_status> -- runs get_workspace_dir
# with the current get_current_pane_path stub, capturing stdout. Sets status to
# 124 if it had to be killed (i.e. it hung).
run_with_timeout() {
    local __out_var="$1" __status_var="$2"
    local tmpfile; tmpfile="$(mktemp)"

    ( get_workspace_dir >"$tmpfile" 2>/dev/null ) &
    local pid=$!

    local waited=0
    while kill -0 "$pid" 2>/dev/null; do
        if (( waited >= TIMEOUT_SECS )); then
            kill -9 "$pid" 2>/dev/null
            wait "$pid" 2>/dev/null
            printf -v "$__out_var" '%s' ""
            printf -v "$__status_var" '%s' "124"
            rm -f "$tmpfile"
            return
        fi
        sleep 1
        (( waited++ ))
    done
    wait "$pid" 2>/dev/null

    printf -v "$__out_var" '%s' "$(cat "$tmpfile")"
    printf -v "$__status_var" '%s' "0"
    rm -f "$tmpfile"
}

# assert <name> <expected> -- stubs get_current_pane_path via $STUB_PATH and
# compares get_workspace_dir output to expected.
assert() {
    local name="$1" expected="$2"
    local out status
    run_with_timeout out status

    if [[ "$status" == "124" ]]; then
        echo "FAIL: $name -- function hung (timed out after ${TIMEOUT_SECS}s)"
        (( failures++ ))
    elif [[ "$out" == "$expected" ]]; then
        echo "PASS: $name"
    else
        echo "FAIL: $name -- expected [$expected], got [$out]"
        (( failures++ ))
    fi
}

# --- Test fixtures -------------------------------------------------------

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Real realpath is needed; only stub the pane path.
stub() { eval "get_current_pane_path() { echo '$1'; }"; }

# Case 1: deleted directory (the regression guard for the infinite loop).
GONE="$WORK/gone"
mkdir -p "$GONE"; rmdir "$GONE"
stub "$GONE"
assert "deleted directory -> empty, no hang" ""

# Case 2: direct match -- dir itself contains .devcontainer.
DIRECT="$WORK/direct"
mkdir -p "$DIRECT/.devcontainer"
stub "$DIRECT"
assert "direct .devcontainer match" "$(realpath "$DIRECT")"

# Case 3: nested match -- nearest ancestor with .devcontainer.
PROJECT="$WORK/project"
mkdir -p "$PROJECT/.devcontainer"
mkdir -p "$PROJECT/a/b/c"
stub "$PROJECT/a/b/c"
assert "nested -> nearest ancestor" "$(realpath "$PROJECT")"

# Case 4: no match anywhere up the tree.
NOMATCH="$WORK/plain/sub"
mkdir -p "$NOMATCH"
stub "$NOMATCH"
assert "no .devcontainer -> empty" ""

# --- Summary -------------------------------------------------------------

echo
if (( failures == 0 )); then
    echo "All tests passed."
    exit 0
else
    echo "$failures test(s) failed."
    exit 1
fi
