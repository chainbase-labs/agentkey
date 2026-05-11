#!/usr/bin/env bash
# Shared bats helpers — isolate HOME, TMPDIR, network for each test.

setup_isolated_env() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    export TEST_TMP="$(mktemp -d)"
    export HOME="$TEST_TMP/home"
    export TMPDIR="$TEST_TMP/tmp"
    export XDG_CONFIG_HOME="$HOME/.config"
    mkdir -p "$HOME" "$TMPDIR" "$XDG_CONFIG_HOME/agentkey"

    # Use a copy of the plugin root so tests can mutate version.txt etc
    export PLUGIN_ROOT="$TEST_TMP/plugin"
    mkdir -p "$PLUGIN_ROOT/skills/agentkey/scripts"
    cp "$REPO_ROOT/skills/agentkey/scripts/check-update.sh" \
       "$PLUGIN_ROOT/skills/agentkey/scripts/check-update.sh"
    # version.txt may not exist yet (version is currently embedded in check-update.sh);
    # later tasks will introduce it. Copy if present, otherwise skip silently.
    if [ -f "$REPO_ROOT/version.txt" ]; then
        cp "$REPO_ROOT/version.txt" "$PLUGIN_ROOT/version.txt"
    fi
    export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"

    # Block real network — every test must mock curl
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
