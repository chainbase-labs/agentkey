#!/usr/bin/env bats
load helpers

setup() {
    setup_isolated_env
}

teardown() {
    teardown_isolated_env
}

@test "check-update.sh exits silently when version.txt missing" {
    rm -f "$PLUGIN_ROOT/version.txt"
    run bash "$PLUGIN_ROOT/skills/agentkey/scripts/check-update.sh"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
