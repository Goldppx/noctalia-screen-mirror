#!/usr/bin/env sh
# Screen Mirror - installer.
#
# Registers this checkout as a Noctalia plugin source and enables the plugin.
# Nothing is written outside the user's own config/state directories and no root
# is needed; the mirroring engine itself is the niri-mirror daemon.
#
#   ./install.sh              # register + enable, then print next steps
#   SOURCE_NAME=my-plugins ./install.sh
set -eu

PLUGIN_ID="goldesquemoon/screen-mirror"
SOURCE_NAME="${SOURCE_NAME:-screen-mirror}"
REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

for arg in "$@"; do
    case "$arg" in
    -h | --help)
        sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'
        exit 0
        ;;
    *)
        printf 'install: unknown option %s\n' "$arg" >&2
        exit 2
        ;;
    esac
done

die() {
    printf 'install: %s\n' "$*" >&2
    exit 1
}
have() { command -v "$1" >/dev/null 2>&1; }

have noctalia || die "noctalia CLI not found in PATH"
have niri || printf 'install: warning: niri not in PATH - the daemon needs it\n' >&2
have wl-mirror || printf 'install: warning: wl-mirror missing - install it (pacman -S wl-mirror)\n' >&2
if ! have niri-mirror && [ ! -x "$HOME/.local/bin/niri-mirror" ]; then
    printf 'install: warning: the niri-mirror daemon is missing.\n' >&2
    printf 'install:          run install.sh from https://github.com/Goldppx/niri-mirror first.\n' >&2
fi

# 1. plugin source (idempotent)
if noctalia msg plugins source list 2>/dev/null | awk '{print $1}' | grep -qx "$SOURCE_NAME"; then
    printf 'source "%s" already registered\n' "$SOURCE_NAME"
else
    noctalia msg plugins source add "$SOURCE_NAME" path "$REPO_DIR" >/dev/null
    printf 'registered source "%s" -> %s\n' "$SOURCE_NAME" "$REPO_DIR"
fi

# 2. enable (idempotent)
noctalia msg plugins enable "$PLUGIN_ID" >/dev/null
printf 'enabled %s\n' "$PLUGIN_ID"

cat <<EOT

Next steps
  1. Control-center tile: Settings -> Control Center -> Shortcuts -> "Screen Mirror"
     (config.toml equivalent:)

     [[control_center.shortcuts]]
     type = "${PLUGIN_ID}:mirror"

  2. Optional bar widget: Settings -> Bar -> add widget "Screen Mirror"

  3. Settings -> Plugins -> Screen Mirror: OSD feedback, enabled on start,
     source display, excluded displays, scaling.

  4. Optional keybind that works without Noctalia:

     binds {
         Mod+U { spawn-sh "~/.local/bin/niri-mirror toggle"; }
     }

Verify
  noctalia msg plugins list | grep screen-mirror
  niri-mirror --list-outputs
  sh ${REPO_DIR}/tests/smoke.sh
EOT
