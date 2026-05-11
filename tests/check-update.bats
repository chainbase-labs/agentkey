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
    # Disable telemetry so the silent-exit contract is unaffected by Task 3's
    # emit on the update-disabled branch.
    touch "$XDG_CONFIG_HOME/agentkey/telemetry-disabled"
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

@test "emits TELEMETRY skill_loaded up_to_date when versions match" {
    set_local_version "1.0.0"
    mock_curl_release "v1.0.0"
    run_check_update
    [ "$status" -eq 0 ]
    [[ "$output" == *"UP_TO_DATE"* ]]
    [[ "$output" == *"TELEMETRY skill_loaded"* ]]
    [[ "$output" == *"update_state=up_to_date"* ]]
    [[ "$output" == *"skill_version=1.0.0"* ]]
}

@test "emits TELEMETRY skill_loaded upgrade_available when newer release exists" {
    set_local_version "1.0.0"
    mock_curl_release "v2.0.0"
    run_check_update
    [ "$status" -eq 0 ]
    [[ "$output" == *"UPGRADE_AVAILABLE 1.0.0 2.0.0"* ]]
    [[ "$output" == *"TELEMETRY skill_loaded"* ]]
    [[ "$output" == *"update_state=upgrade_available"* ]]
    [[ "$output" == *"latest_version=2.0.0"* ]]
}

@test "emits TELEMETRY skill_loaded disabled when update-disabled file exists" {
    touch "$XDG_CONFIG_HOME/agentkey/update-disabled"
    set_local_version "1.0.0"
    # 注意 update-disabled 早返发生在 curl 之前，所以不需要 mock_curl_release。
    run_check_update
    [ "$status" -eq 0 ]
    [[ "$output" == *"TELEMETRY skill_loaded"* ]]
    [[ "$output" == *"update_state=disabled"* ]]
    # update-disabled 不应再输出 UP_TO_DATE / UPGRADE_AVAILABLE 主行
    [[ "$output" != *"UP_TO_DATE"* ]]
    [[ "$output" != *"UPGRADE_AVAILABLE"* ]]
}

@test "second invocation within 24h does not re-emit telemetry" {
    set_local_version "1.0.0"
    mock_curl_release "v1.0.0"
    run_check_update
    [[ "$output" == *"TELEMETRY skill_loaded"* ]]

    run_check_update
    [[ "$output" == *"UP_TO_DATE"* ]]
    [[ "$output" != *"TELEMETRY"* ]]
}

@test "AGENTKEY_TELEMETRY=0 disables emit" {
    set_local_version "1.0.0"
    mock_curl_release "v1.0.0"
    AGENTKEY_TELEMETRY=0 run_check_update
    [[ "$output" == *"UP_TO_DATE"* ]]
    [[ "$output" != *"TELEMETRY"* ]]
}

@test "telemetry-disabled file disables emit" {
    set_local_version "1.0.0"
    mock_curl_release "v1.0.0"
    touch "$XDG_CONFIG_HOME/agentkey/telemetry-disabled"
    run_check_update
    [[ "$output" == *"UP_TO_DATE"* ]]
    [[ "$output" != *"TELEMETRY"* ]]
}

@test "emits auto_upgrade_enabled=1 when auto-upgrade file exists" {
    set_local_version "1.0.0"
    mock_curl_release "v1.0.0"
    touch "$XDG_CONFIG_HOME/agentkey/auto-upgrade"
    run_check_update
    [[ "$output" == *"auto_upgrade_enabled=1"* ]]
}
