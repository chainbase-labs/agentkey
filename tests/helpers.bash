#!/usr/bin/env bash
# Shared bats helpers — isolate HOME, TMPDIR, network per test.
# main 上的 check-update.sh 把版本内嵌在脚本里
# (`LOCAL_VERSION="x.y.z" # x-release-please-version`)，本 helper 提供
# `set_local_version` 直接覆盖那一行以模拟不同的本地版本。

setup_isolated_env() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    export TEST_TMP="$(mktemp -d)"
    export HOME="$TEST_TMP/home"
    export TMPDIR="$TEST_TMP/tmp"
    export XDG_CONFIG_HOME="$HOME/.config"
    mkdir -p "$HOME" "$TMPDIR" "$XDG_CONFIG_HOME/agentkey"

    # Copy the script into the test sandbox so we can mutate LOCAL_VERSION.
    export SCRIPT_DIR="$TEST_TMP/scripts"
    export SCRIPT="$SCRIPT_DIR/check-update.sh"
    mkdir -p "$SCRIPT_DIR"
    cp "$REPO_ROOT/skills/agentkey/scripts/check-update.sh" "$SCRIPT"

    # Block real network — every test must call mock_curl_release explicitly.
    mkdir -p "$TEST_TMP/bin"
    cat > "$TEST_TMP/bin/curl" <<'EOF'
#!/usr/bin/env bash
echo "ERROR: curl not mocked in this test" >&2
exit 7
EOF
    chmod +x "$TEST_TMP/bin/curl"
    export PATH="$TEST_TMP/bin:$PATH"
}

teardown_isolated_env() {
    [ -n "$TEST_TMP" ] && rm -rf "$TEST_TMP"
}

# Mock curl to return a fixed GitHub /releases/latest payload.
mock_curl_release() {
    local tag="$1"
    cat > "$TEST_TMP/bin/curl" <<EOF
#!/usr/bin/env bash
echo '{"tag_name":"$tag"}'
EOF
    chmod +x "$TEST_TMP/bin/curl"
}

# Override the embedded LOCAL_VERSION in the sandboxed copy of check-update.sh.
set_local_version() {
    local v="$1"
    # GNU sed and BSD sed both accept this in-place form on Linux/macOS via the
    # trailing empty string trick: use a portable sed wrapper.
    if sed --version >/dev/null 2>&1; then
        sed -i "s/^LOCAL_VERSION=.*/LOCAL_VERSION=\"$v\" # x-release-please-version/" "$SCRIPT"
    else
        sed -i '' "s/^LOCAL_VERSION=.*/LOCAL_VERSION=\"$v\" # x-release-please-version/" "$SCRIPT"
    fi
}

# Run the sandboxed check-update.sh and capture status + output.
run_check_update() {
    run bash "$SCRIPT" "$@"
}
