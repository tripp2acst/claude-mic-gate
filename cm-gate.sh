#!/usr/bin/env bash
# cm-gate.sh — play $1 as a sound, UNLESS the mic is live (i.e. you're on a call),
# in which case post a silent notification banner ($2) instead of making noise.
# Used by Claude Code Notification/Stop hooks defined in ~/.claude/settings.json.
#
#   Usage: cm-gate.sh <sound-file> [notification-message]
#
# Meeting detection: we DON'T look at whether Teams/Zoom is running — new Teams
# keeps ~15 helper processes (and the camera daemon appleh16camerad) alive 24/7,
# so process/CoreAudio-open checks false-positive any time the app is merely open
# (that's why the old `lsof | grep CoreAudio` gate was ripped out). Instead we ask
# CoreAudio directly whether any *input* device is running right now, via the
# compiled `mic-in-use` helper — the same signal behind the macOS orange mic dot.
# That's true only during an actual call (Teams/Zoom/Meet/FaceTime/phone), false
# when the app is idle. Validated on Apple Silicon + a live Teams call.
#
# Fail-open: if the helper is missing or errors, we play the sound. Worst case is
# the old always-on behavior, never silent-forever. Rebuild the helper with:
#   swiftc -O ~/.claude/hooks/mic-in-use.swift -o ~/.claude/hooks/mic-in-use

SOUND="$1"
MSG="${2:-Claude Code needs your attention}"   # shown as a silent banner while on a call
[[ -z "$SOUND" || ! -f "$SOUND" ]] && exit 0

# On a call (mic live): stay silent, but still alert you with a visual banner
# that names the project + IDE, so you can tell multiple sessions apart.
MIC="$(dirname "$0")/mic-in-use"
if [[ -x "$MIC" ]] && "$MIC"; then
  # Which project? Prefer the hook payload's cwd (read only when stdin is piped,
  # so manual runs on a tty don't hang); fall back to the hook's working dir.
  PROJECT=""
  if [[ ! -t 0 ]]; then
    PROJECT="$(/usr/bin/python3 -c 'import sys,json,os;print(os.path.basename(json.load(sys.stdin).get("cwd","")))' 2>/dev/null)"
  fi
  [[ -z "$PROJECT" ]] && PROJECT="$(basename "$PWD")"

  # Which IDE/terminal? Best-effort from TERM_PROGRAM.
  case "$TERM_PROGRAM" in
    vscode)         IDE="VS Code" ;;
    iTerm.app)      IDE="iTerm" ;;
    Apple_Terminal) IDE="Terminal" ;;
    WarpTerminal)   IDE="Warp" ;;
    ghostty)        IDE="Ghostty" ;;
    Hyper)          IDE="Hyper" ;;
    *)              IDE="$TERM_PROGRAM" ;;
  esac

  SUB="$PROJECT"
  [[ -n "$IDE" ]] && SUB="$PROJECT · $IDE"

  # strip double-quotes so values can't break the AppleScript string
  osascript -e "display notification \"${MSG//\"/}\" with title \"Claude Code\" subtitle \"${SUB//\"/}\"" >/dev/null 2>&1
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
