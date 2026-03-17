#!/bin/bash
# sync-static.sh — Copy root-level distributable files to static/ for Hugo site.
# Run before Hugo build to ensure the website serves the latest versions.
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
STATIC="$BASE_DIR/static"

# Shell scripts
for f in run-agent.sh monitor-agents.sh watch-agents.sh status-loop.sh status-loop-5m.sh run-agent-tests.sh test-claude-run.sh; do
  [ -f "$BASE_DIR/$f" ] && cp "$BASE_DIR/$f" "$STATIC/$f"
done

# Prompt files
for f in "$BASE_DIR"/THE_PROMPT_v5*.md; do
  [ -f "$f" ] && cp "$f" "$STATIC/$(basename "$f")"
done

# Other distributable files
for f in MESSAGE-BUS.md LICENSE AGENTS.md; do
  [ -f "$BASE_DIR/$f" ] && cp "$BASE_DIR/$f" "$STATIC/$f"
done

echo "static/ synced with $(ls "$STATIC"/*.sh "$STATIC"/*.md 2>/dev/null | wc -l | tr -d ' ') files"
