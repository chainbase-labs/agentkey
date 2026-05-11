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

@test "telemetry-disabled file does not break existing update flow" {
    touch "$XDG_CONFIG_HOME/agentkey/telemetry-disabled"
    set_local_version "1.0.0"
    mock_curl_release "v1.0.0"
    run_check_update
    [ "$status" -eq 0 ]
    # 行为不变：UP_TO_DATE 仍然输出
    [[ "$output" == *"UP_TO_DATE"* ]]
    # Task 2 还没引入 emit，Task 3 才会加；此处主要保 telemetry-disabled 文件不会
    # 让脚本崩。
}
