#!/bin/bash
# Deploy the fork's netcoredbg build into the free-vscode-csharp extension bundled
# debugger directory (VSCodium). The stock debugger is backed up next to it the
# first time; run with --restore to put the original back.
#
# Extension updates replace the .debugger directory - just re-run this script after.
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

for TARGET in "${TARGETS[@]}"; do
    BACKUP="$TARGET.stock"
    if [ "$1" = "--restore" ]; then
        if [ -d "$BACKUP" ]; then
            rm -rf "$TARGET"
            mv "$BACKUP" "$TARGET"
            echo "restored stock debugger: $TARGET"
        else
            echo "no backup found for: $TARGET" >&2
        fi
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
done
