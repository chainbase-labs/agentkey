#!/usr/bin/env bats
load helpers

setup() {
    setup_isolated_env
}

teardown() {
    teardown_isolated_env
}

@test "exits silently when update-disabled file exists" {
    touch "$XDG_CONFIG_HOME/agentkey/update-disabled"
    run_check_update
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "set_local_version helper correctly overrides embedded version" {
    set_local_version "9.9.9"
    grep -q '^LOCAL_VERSION="9.9.9"' "$SCRIPT"
}
