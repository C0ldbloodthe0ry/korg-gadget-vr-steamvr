#!/usr/bin/env bash
# Undo install.sh. Same as: ./install.sh --uninstall [game folder]
exec "$(cd "$(dirname "$0")" && pwd)/install.sh" --uninstall "$@"
