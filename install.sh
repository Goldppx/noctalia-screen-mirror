#!/usr/bin/env sh
# Screen Mirror - installer.
#
# Registers this checkout as a Noctalia plugin source, enables the plugin, and
# makes sure the mirroring engine (the `niri-mirror` daemon) is installed: if the
# CLI is missing, its repository is cloned and its install.sh is run, which puts
# niri-mirror into ~/.local/bin and adds the autostart entry to the niri config.
# Nothing here needs root.
#
#   ./install.sh                # check/install the daemon, register, enable
#   ./install.sh --no-daemon    # only check the daemon, never fetch it
#   NIRI_MIRROR_DIR=~/dev/niri-mirror ./install.sh   # use a local checkout
#   SOURCE_NAME=my-plugins ./install.sh
set -eu

PLUGIN_ID="goldesquemoon/screen-mirror"
SOURCE_NAME="${SOURCE_NAME:-screen-mirror}"
REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
NIRI_MIRROR_REPO="${NIRI_MIRROR_REPO:-https://github.com/Goldppx/niri-mirror.git}"
NIRI_MIRROR_DIR="${NIRI_MIRROR_DIR:-}"
SKIP_DAEMON=0

for arg in "$@"; do
    case "$arg" in
    --no-daemon) SKIP_DAEMON=1 ;;
    -h | --help)
        awk 'NR > 1 { if (!/^#/) exit; sub(/^# ?/, ""); print }' "$0"
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

# The engine is the companion daemon: it owns the niri event stream, the
# wl-mirror windows and the state file this plugin reads.
daemon_bin() {
    if have niri-mirror; then
        command -v niri-mirror
        return 0
    fi
    if [ -x "$HOME/.local/bin/niri-mirror" ]; then
        printf '%s\n' "$HOME/.local/bin/niri-mirror"
        return 0
    fi
    return 1
}

ensure_daemon() {
    if bin=$(daemon_bin); then
        printf 'daemon: found %s\n' "$bin"
        return 0
    fi

    if [ "$SKIP_DAEMON" -eq 1 ]; then
        printf 'install: warning: niri-mirror is missing and --no-daemon was given\n' >&2
        printf 'install:          install it from %s\n' "${NIRI_MIRROR_REPO%.git}" >&2
        return 0
    fi

    src=${NIRI_MIRROR_DIR}
    if [ -z "$src" ] && [ -f "$REPO_DIR/../niri-mirror/install.sh" ]; then
        src=$(CDPATH= cd -- "$REPO_DIR/../niri-mirror" && pwd)
        printf 'daemon: using the checkout next to this repo (%s)\n' "$src"
    fi

    tmp=
    if [ -z "$src" ]; then
        have git || die "git is required to fetch niri-mirror (or set NIRI_MIRROR_DIR to a checkout)"
        tmp=$(mktemp -d)
        printf 'daemon: cloning %s\n' "$NIRI_MIRROR_REPO"
        if ! git clone -q --depth=1 "$NIRI_MIRROR_REPO" "$tmp/niri-mirror"; then
            rm -rf "$tmp"
            die "could not clone niri-mirror - check the network, or clone it yourself and set NIRI_MIRROR_DIR"
        fi
        src="$tmp/niri-mirror"
    fi

    [ -f "$src/install.sh" ] || die "$src has no install.sh"
    printf 'daemon: running %s/install.sh\n' "$src"
    if have bash; then
        (cd "$src" && bash ./install.sh)
    else
        (cd "$src" && sh ./install.sh)
    fi

    [ -n "$tmp" ] && rm -rf "$tmp"

    if bin=$(daemon_bin); then
        printf 'daemon: installed %s\n' "$bin"
    else
        die "the daemon's install.sh ran but niri-mirror is still not on PATH or in ~/.local/bin"
    fi
}

ensure_daemon

if ! have wl-mirror; then
    printf 'install: warning: wl-mirror is missing - install it, e.g. pacman -S wl-mirror\n' >&2
fi
have niri || printf 'install: warning: niri not in PATH - the daemon needs it\n' >&2

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

  4. Keybind. The daemon's installer added a niri bind for
     "~/.local/bin/niri-mirror toggle" when it found your niri config; through the
     plugin the same toggle is:

     binds {
         Mod+U { spawn-sh "noctalia msg plugin ${PLUGIN_ID}:state all toggle"; }
     }

  5. The daemon starts from the niri autostart entry the installer added. If the
     tile says it is not running, log out and back in, or start it once:

     ~/.local/bin/niri-mirror --log-file ~/.local/state/niri-mirror/daemon.log &

Verify
  noctalia msg plugins list | grep screen-mirror
  niri-mirror --list-outputs
  sh ${REPO_DIR}/tests/smoke.sh
EOT
