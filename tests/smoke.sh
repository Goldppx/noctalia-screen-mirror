#!/usr/bin/env sh
# Screen Mirror - smoke test (no root, read-only, no compositor needed).
#
#   sh tests/smoke.sh
#
# Checks the manifest, the entry wiring, the settings schema, that every
# label_key/description_key resolves in both translation files, and that the
# catalog row matches the plugin manifest.
set -eu

REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
PLUGIN_DIR="$REPO_DIR/screen-mirror"
MANIFEST="$PLUGIN_DIR/plugin.toml"
CATALOG="$REPO_DIR/catalog.toml"
PLUGIN_ID="goldesquemoon/screen-mirror"
fail=0
ok() { printf '  ok    %s\n' "$1"; }
bad() {
    printf '  FAIL  %s\n' "$1" >&2
    fail=$((fail + 1))
}
check() { # description, exit code
    if [ "$2" -eq 0 ]; then ok "$1"; else bad "$1"; fi
}

printf 'manifest\n'
for key in id name version plugin_api author license; do
    grep -qE "^$key[[:space:]]*=" "$MANIFEST"
    check "has $key" $?
done
grep -q "^id[[:space:]]*=[[:space:]]*\"$PLUGIN_ID\"" "$MANIFEST"
check "id is $PLUGIN_ID" $?
grep -qE '^plugin_api[[:space:]]*=[[:space:]]*[0-9]+' "$MANIFEST"
check 'plugin_api is an integer' $?
grep -qE '^dependencies[[:space:]]*=' "$MANIFEST"
check 'declares its dependencies' $?

printf 'entries\n'
entries=$(mktemp)
ids=$(mktemp)
awk -F'"' '/^entry[[:space:]]*=/ { print id, $2 } /^id[[:space:]]*=/ { id = $2 }' "$MANIFEST" >"$entries"
while read -r id entry; do
    [ -n "${entry:-}" ] || continue
    if [ -f "$PLUGIN_DIR/$entry" ]; then
        ok "$id -> $entry"
    else
        bad "$id -> $entry missing"
    fi
    printf '%s\n' "$id" >>"$ids"
done <"$entries"
if [ -s "$ids" ] && [ "$(sort "$ids" | uniq -d | wc -l)" -eq 0 ]; then
    ok 'entry ids are unique'
else
    bad 'entry ids are unique'
fi
rm -f "$entries" "$ids"

printf 'settings + translations\n'
python3 - "$MANIFEST" "$PLUGIN_DIR/translations" <<'PY'
import json
import pathlib
import sys

manifest = pathlib.Path(sys.argv[1]).read_text().splitlines()
translations = pathlib.Path(sys.argv[2])
lanes = {}
for path in translations.glob("*.json"):
    lanes[path.stem] = json.loads(path.read_text())

keys = []
for line in manifest:
    stripped = line.strip()
    for field in ("label_key", "description_key"):
        if stripped.startswith(field) and "=" in stripped:
            keys.append(stripped.split("=", 1)[1].strip().strip('"'))

problems = 0
for key in keys:
    parts = key.split(".")
    for lane, data in lanes.items():
        node = data
        for part in parts:
            if not isinstance(node, dict) or part not in node:
                print(f"  FAIL  {lane}: missing translation key {key}", file=sys.stderr)
                problems += 1
                break
            node = node[part]
print(f"  ok    {len(keys)} setting labels/descriptions resolve in {', '.join(sorted(lanes))}")
if problems:
    sys.exit(1)
PY
check 'translation keys resolve' $?

printf 'catalog\n'
grep -q "^id = \"$PLUGIN_ID\"" "$CATALOG"
check 'catalog lists the plugin' $?
manifest_version=$(grep -E '^version[[:space:]]*=' "$MANIFEST" | head -1 | sed 's/.*"\(.*\)".*/\1/')
grep -q "^version = \"$manifest_version\"" "$CATALOG"
check "catalog version matches plugin.toml ($manifest_version)" $?

printf 'scripts\n'
sh -n "$REPO_DIR/install.sh"
check 'install.sh parses' $?
sh -n "$REPO_DIR/uninstall.sh"
check 'uninstall.sh parses' $?

printf '\n'
if [ "$fail" -ne 0 ]; then
    printf '%s check(s) failed\n' "$fail" >&2
    exit 1
fi
printf 'all checks passed\n'
