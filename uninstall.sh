#!/usr/bin/env sh
# Screen Mirror - uninstaller.
#
#   ./uninstall.sh           # disable the plugin, keep the daemon and its config
#   ./uninstall.sh --purge   # also stop the daemon and delete its config/state
set -eu

PLUGIN_ID="goldesquemoon/screen-mirror"
PURGE=0

for arg in "$@"; do
    case "$arg" in
    --purge) PURGE=1 ;;
    -h | --help)
        sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'
        exit 0
        ;;
    *)
        printf 'uninstall: unknown option %s\n' "$arg" >&2
        exit 2
        ;;
    esac
done

if command -v noctalia >/dev/null 2>&1; then
    noctalia msg plugins disable "$PLUGIN_ID" >/dev/null 2>&1 || true
    printf 'disabled %s\n' "$PLUGIN_ID"
fi

if [ "$PURGE" -eq 1 ]; then
    if [ -x "$HOME/.local/bin/niri-mirror" ]; then
        "$HOME/.local/bin/niri-mirror" off >/dev/null 2>&1 || true
        "$HOME/.local/bin/niri-mirror" quit >/dev/null 2>&1 || true
    fi
    rm -rf "$HOME/.config/niri-mirror" "$HOME/.local/state/niri-mirror"
    printf 'removed niri-mirror config and state\n'
fi
