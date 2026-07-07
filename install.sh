#!/usr/bin/env bash
# install.sh — compile mic-in-use and install the gate into ~/.claude/hooks.
set -euo pipefail

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOKS_DIR="$HOME/.claude/hooks"

if ! command -v swiftc >/dev/null 2>&1; then
  echo "error: swiftc not found. Install the Swift toolchain first:" >&2
  echo "  xcode-select --install" >&2
  exit 1
fi

mkdir -p "$HOOKS_DIR"

echo "Compiling mic-in-use..."
swiftc -O "$SRC_DIR/mic-in-use.swift" -o "$HOOKS_DIR/mic-in-use"

echo "Installing cm-gate.sh..."
cp "$SRC_DIR/cm-gate.sh" "$HOOKS_DIR/cm-gate.sh"
chmod +x "$HOOKS_DIR/cm-gate.sh"

# Sanity check: idle mic should report "not in use" (exit 1).
if "$HOOKS_DIR/mic-in-use"; then
  echo "note: mic-in-use reports the mic is currently LIVE (are you on a call?)."
else
  echo "ok: mic-in-use reports the mic is idle."
fi

cat <<'EOF'

Installed to ~/.claude/hooks/ (mic-in-use, cm-gate.sh).

Now point your sound hooks at cm-gate.sh in ~/.claude/settings.json, e.g.:

  "Stop": [
    { "hooks": [
        { "type": "command",
          "command": "bash ~/.claude/hooks/cm-gate.sh ~/sounds/done.mp3" }
    ] }
  ]

Restart Claude Code afterward (hooks are read at session start).
EOF
