#!/usr/bin/env bash
# claude-status installer
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
STATUS_SCRIPT="$CLAUDE_DIR/claude-status.sh"

echo "Installing claude-status..."

# Copy the script
cp "$SCRIPT_DIR/claude-status.sh" "$STATUS_SCRIPT"
chmod +x "$STATUS_SCRIPT"
echo "  Copied claude-status.sh to $STATUS_SCRIPT"

# Update settings.json
if [ ! -f "$SETTINGS_FILE" ]; then
  echo '{}' > "$SETTINGS_FILE"
fi

# Check if statusLine is already configured
if python3 -c "
import json, sys
with open('$SETTINGS_FILE') as f:
    data = json.load(f)
if 'statusLine' in data:
    sys.exit(1)
" 2>/dev/null; then
  # Add statusLine config
  python3 -c "
import json
with open('$SETTINGS_FILE') as f:
    data = json.load(f)
data['statusLine'] = {
    'type': 'command',
    'command': '~/.claude/claude-status.sh'
}
with open('$SETTINGS_FILE', 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
"
  echo "  Added statusLine config to $SETTINGS_FILE"
else
  echo "  statusLine already configured in $SETTINGS_FILE — skipping"
fi

echo ""
echo "Done! Restart Claude Code to see the token burn status line."
