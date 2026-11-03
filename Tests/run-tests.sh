#!/bin/bash
# Checks the shift maths (phases, night shifts, daylight saving, time zones, late starts,
# timeline entries), the shared file's format and migration from Shift Countdown, widget
# theme contrast, the break rounds, the Pomodoro timer, the history format, and the habit rules
# (break routine, water pace, goal, streak).
set -euo pipefail
cd "$(dirname "$0")/.."

if [ -z "${DEVELOPER_DIR:-}" ]; then
    selected="$(xcode-select -p 2>/dev/null || true)"
    case "$selected" in
        *Xcode*) export DEVELOPER_DIR="$selected" ;;
        *) export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" ;;
    esac
fi

OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

xcrun swiftc -swift-version 5 -O -o "$OUT/tests" \
    Sources/Shared/*.swift \
    Sources/Eyebreak/BreakRound.swift \
    Sources/Eyebreak/Pomodoro.swift \
    Sources/Eyebreak/StatsStore.swift \
    Sources/Eyebreak/Habits.swift \
    Tests/main.swift

# Fixed zone so the cases that follow "this Mac" are reproducible anywhere.
TZ=Europe/Paris "$OUT/tests"
