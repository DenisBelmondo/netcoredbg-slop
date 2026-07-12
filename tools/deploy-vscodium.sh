#!/bin/bash
# Deploy the fork's netcoredbg build into the free-vscode-csharp extension bundled
# debugger directory (VSCodium). The stock debugger is backed up next to it the
# first time; run with --restore to put the original back.
#
# Also patches the extension's package.json so the launch.json schema knows the
# fork's "nonUserModules" option (no editor squiggles, autocomplete works).
# Fully restart VSCodium after patching - the manifest is read at startup.
#
# Extension updates replace the .debugger directory and package.json - just
# re-run this script after.
set -e

BIN_DIR="$(cd "$(dirname "$0")/.." && pwd)/bin"
EXT_GLOB="$HOME/.vscode-oss/extensions/muhammad-sammy.csharp-*/.debugger/netcoredbg"

shopt -s nullglob
TARGETS=($EXT_GLOB)
shopt -u nullglob

if [ ${#TARGETS[@]} -eq 0 ]; then
    echo "error: no extension debugger directory found matching: $EXT_GLOB" >&2
    exit 1
fi

patch_schema()
{
    local mode=$1 pkg=$2
    python3 - "$mode" "$pkg" <<'EOF'
import json, sys

mode, path = sys.argv[1], sys.argv[2]
with open(path) as f:
    pkg = json.load(f)

schema = {
    "type": "array",
    "items": {"type": "string"},
    "default": [],
    "markdownDescription": "Glob patterns (`*`, `?`, case-insensitive) of modules to treat as non-user code for Just My Code, even when their symbols are loaded. Patterns containing a path separator match the full module path, otherwise the module file name. Example: `[\"GodotSharp*\", \"GodotPlugins*\"]`. Fork-specific option of netcoredbg-slop.",
}

changed = False
for dbg in pkg.get("contributes", {}).get("debuggers", []):
    if dbg.get("type") != "coreclr":
        continue
    for request in ("launch", "attach"):
        props = dbg.get("configurationAttributes", {}).get(request, {}).get("properties")
        if props is None:
            continue
        if mode == "remove":
            changed |= props.pop("nonUserModules", None) is not None
        elif props.get("nonUserModules") != schema:
            props["nonUserModules"] = schema
            changed = True

if changed:
    with open(path, "w") as f:
        json.dump(pkg, f, indent=2, ensure_ascii=False)
        f.write("\n")
print(("patched" if mode == "add" else "unpatched") if changed else "already up to date", "schema:", path)
EOF
}

for TARGET in "${TARGETS[@]}"; do
    BACKUP="$TARGET.stock"
    PKG_JSON="$(dirname "$(dirname "$TARGET")")/package.json"
    if [ "$1" = "--restore" ]; then
        if [ -d "$BACKUP" ]; then
            rm -rf "$TARGET"
            mv "$BACKUP" "$TARGET"
            echo "restored stock debugger: $TARGET"
        else
            echo "no backup found for: $TARGET" >&2
        fi
        [ -f "$PKG_JSON" ] && patch_schema remove "$PKG_JSON"
        continue
    fi

    if [ ! -x "$BIN_DIR/netcoredbg" ]; then
        echo "error: fork build not found at $BIN_DIR/netcoredbg (run 'ninja install' in build/ first)" >&2
        exit 1
    fi

    if [ ! -d "$BACKUP" ]; then
        cp -a "$TARGET" "$BACKUP"
        echo "backed up stock debugger to: $BACKUP"
    fi

    cp -a "$BIN_DIR/." "$TARGET/"
    echo "deployed fork build to: $TARGET"

    [ -f "$PKG_JSON" ] && patch_schema add "$PKG_JSON"
done
