#!/usr/bin/env bash
# cm-gate.sh — play $1 as a sound, unless the mic is live (i.e. you're on a call).
# Used by Claude Code Notification/Stop hooks defined in ~/.claude/settings.json.
#
# Meeting detection: we DON'T look at whether Teams/Zoom is running — new Teams
# keeps ~15 helper processes (and the camera daemon appleh16camerad) alive 24/7,
# so process/CoreAudio-open checks false-positive any time the app is merely open
# (that's why the old `lsof | grep CoreAudio` gate was ripped out). Instead we ask
# CoreAudio directly whether any *input* device is running right now, via the
# compiled `mic-in-use` helper — the same signal behind the macOS orange mic dot.
# That's true only during an actual call (Teams/Zoom/Meet/FaceTime/phone), false
# when the app is idle. Validated on Apple Silicon: idle->skip, recording->suppress.
#
# Fail-open: if the helper is missing or errors, we play the sound. Worst case is
# the old always-on behavior, never silent-forever. Rebuild the helper with:
#   swiftc -O ~/.claude/hooks/mic-in-use.swift -o ~/.claude/hooks/mic-in-use

SOUND="$1"
[[ -z "$SOUND" || ! -f "$SOUND" ]] && exit 0

# Suppress only when the mic is actively capturing (you're on a call).
MIC="$(dirname "$0")/mic-in-use"
if [[ -x "$MIC" ]] && "$MIC"; then
  exit 0
fi

# Detach afplay so it survives the hook process exit:
#   nohup    — ignore SIGHUP
#   &        — background
#   disown   — drop from the shell's job table
#   redirect — detach std streams
nohup afplay "$SOUND" >/dev/null 2>&1 &
disown 2>/dev/null
exit 0
