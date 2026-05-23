#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Logout helper for wlogout and keybind callers.
LOG_FILE="${XDG_RUNTIME_DIR:-/tmp}/hypr-logout.log"

log_msg() {
    printf "[%s] %s\n" "$(date +"%F %T")" "$1" >>"$LOG_FILE"
}

run_logged() {
    local label="$1"
    shift
    log_msg "RUN ${label}: $*"
    "$@" >>"$LOG_FILE" 2>&1
    local rc=$?
    log_msg "RC ${label}: ${rc}"
    return "$rc"
}
logout_completed() {
    # Give the session up to 1 second to terminate after a successful command.
    for _ in {1..10}; do
        pgrep -x Hyprland >/dev/null 2>&1 || return 0
        sleep 0.1
    done
    return 1
}
stop_proc() {
    local name="$1"
    pkill -x -TERM "$name" >/dev/null 2>&1 || true

    # Wait up to 1 second for graceful shutdown.
    for _ in {1..10}; do
        pgrep -x "$name" >/dev/null 2>&1 || return 0
        sleep 0.1
    done

    pkill -x -KILL "$name" >/dev/null 2>&1 || true
}

# Close wlogout if it is still visible.
stop_proc "wlogout"
HYPRCTL_BIN="$(command -v hyprctl || true)"
HYPRSHUTDOWN_BIN="$(command -v hyprshutdown || true)"
UWSM_BIN="$(command -v uwsm || true)"
LOGINCTL_BIN="$(command -v loginctl || true)"

# Preferred path: synchronous hyprshutdown, so script does not silently succeed.
if [ -n "$HYPRSHUTDOWN_BIN" ]; then
    if run_logged "hyprshutdown-no-fork" "$HYPRSHUTDOWN_BIN" --no-fork; then
        if logout_completed; then
            exit 0
        fi
        log_msg "hyprshutdown returned success but Hyprland is still running"
    fi
fi

# Fallback: Lua-compatible dispatch execution for Hyprland 0.55+ Lua workflows.
if [ -n "$HYPRCTL_BIN" ] && [ -n "$HYPRSHUTDOWN_BIN" ]; then
    if run_logged \
        "hyprctl-lua-exec-hyprshutdown" \
        "$HYPRCTL_BIN" dispatch 'hl.dsp.exec_cmd("hyprshutdown --no-fork")'; then
        if logout_completed; then
            exit 0
        fi
        log_msg "hyprctl dispatched hyprshutdown but Hyprland is still running"
    fi
fi

# UWSM-managed session fallback (common on NixOS).
if [ -n "$UWSM_BIN" ]; then
    if run_logged "uwsm-stop" "$UWSM_BIN" stop; then
        if logout_completed; then
            exit 0
        fi
        log_msg "uwsm stop returned success but Hyprland is still running"
    fi
fi

# systemd session fallback.
if [ -n "$LOGINCTL_BIN" ] && [ -n "${XDG_SESSION_ID:-}" ]; then
    if run_logged "loginctl-terminate-session" "$LOGINCTL_BIN" terminate-session "$XDG_SESSION_ID"; then
        if logout_completed; then
            exit 0
        fi
        log_msg "loginctl terminate-session returned success but Hyprland is still running"
    fi
fi

# Last-resort Hyprland exit fallbacks.
if [ -n "$HYPRCTL_BIN" ]; then
    if run_logged "hyprctl-exit" "$HYPRCTL_BIN" dispatch exit; then
        if logout_completed; then
            exit 0
        fi
        log_msg "hyprctl dispatch exit returned success but Hyprland is still running"
    fi
    if run_logged "hyprctl-lua-exit" "$HYPRCTL_BIN" dispatch 'hl.dsp.exit()'; then
        if logout_completed; then
            exit 0
        fi
        log_msg "hyprctl lua exit returned success but Hyprland is still running"
    fi
    if run_logged "hyprctl-legacy-exit" "$HYPRCTL_BIN" dispatch exit x; then
        if logout_completed; then
            exit 0
        fi
        log_msg "hyprctl legacy exit returned success but Hyprland is still running"
    fi
fi

# Final process-level fallback.
if run_logged "pkill-hyprland-term" pkill -x -TERM Hyprland; then
    if logout_completed; then
        exit 0
    fi
    log_msg "SIGTERM sent to Hyprland but process is still running"
fi
if run_logged "pkill-hyprland-kill" pkill -x -KILL Hyprland; then
    exit 0
fi

log_msg "Logout failed: no method succeeded"

exit 1
