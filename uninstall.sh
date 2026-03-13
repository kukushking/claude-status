#!/usr/bin/env bash
# claude-status uninstaller
set -e

CLAUDE_DIR="$HOME/.claude"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
STATUS_SCRIPT="$CLAUDE_DIR/claude-status.sh"

echo "Uninstalling claude-status..."

# Remove the script
if [ -f "$STATUS_SCRIPT" ]; then
  rm "$STATUS_SCRIPT"
  echo "  Removed $STATUS_SCRIPT"
fi

# Remove statusLine from settings.json
if [ -f "$SETTINGS_FILE" ]; then
  python3 -c "
import json
with open('$SETTINGS_FILE') as f:
    data = json.load(f)
if 'statusLine' in data:
    del data['statusLine']
    with open('$SETTINGS_FILE', 'w') as f:
        json.dump(data, f, indent=2)
        f.write('\n')
    print('  Removed statusLine config from settings.json')
else:
    print('  No statusLine config found in settings.json')
"
fi

echo ""
echo "Done! Restart Claude Code to apply changes."
