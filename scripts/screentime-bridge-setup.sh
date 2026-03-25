#!/bin/bash
# ============================================================================
# TimeBudget — Screen Time Bridge Setup
# ============================================================================
# This script sets up the Mac as a data bridge between iOS Screen Time
# and ActivityWatch. It clones aw-import-screentime from GitHub, installs
# it with uv, and creates a launchd job that runs every hour.
#
# Prerequisites:
#   - Homebrew installed
#   - ActivityWatch running on this Mac (http://localhost:5600)
#   - Screen Time enabled on iPhone with "Share Across Devices" ON
#     (Settings → Screen Time → Share Across Devices)
#   - Full Disk Access granted to your terminal (see step below)
#
# Usage:
#   chmod +x scripts/screentime-bridge-setup.sh
#   ./scripts/screentime-bridge-setup.sh
# ============================================================================

set -e

PLIST_NAME="com.timebudget.screentime-import"
PLIST_PATH="$HOME/Library/LaunchAgents/${PLIST_NAME}.plist"
LOG_DIR="$HOME/Library/Logs/TimeBudget"
INSTALL_DIR="$HOME/.local/share/aw-import-screentime"

echo "=========================================="
echo "  TimeBudget Screen Time Bridge Setup"
echo "=========================================="
echo ""

# Step 1: Install uv (Python package manager)
echo "Step 1: Installing dependencies..."
if ! command -v uv &> /dev/null; then
    echo "  Installing uv via Homebrew..."
    brew install uv
fi
echo "  ✓ uv is available"

# Step 2: Clone and install aw-import-screentime
echo ""
echo "Step 2: Installing aw-import-screentime from GitHub..."
if [ -d "$INSTALL_DIR" ]; then
    echo "  Updating existing installation..."
    cd "$INSTALL_DIR"
    git pull --quiet
else
    echo "  Cloning repository..."
    git clone --quiet https://github.com/ActivityWatch/aw-import-screentime.git "$INSTALL_DIR"
    cd "$INSTALL_DIR"
fi

echo "  Syncing dependencies with uv..."
uv sync --quiet
echo "  ✓ Installed at $INSTALL_DIR"
echo ""

# The command runs through uv in the project venv
AW_CMD="uv run --project $INSTALL_DIR aw-import-screentime"

# Step 3: Full Disk Access
echo "Step 3: Full Disk Access"
echo "  The script needs to read ~/Library/Biome/streams/restricted/"
echo ""
echo "  → Open: System Settings → Privacy & Security → Full Disk Access"
echo "  → Click '+' and add your terminal app (Terminal, iTerm, Warp, etc.)"
echo ""
echo "  Also ensure on your iPhone:"
echo "  → Settings → Screen Time → Share Across Devices → ON"
echo ""
echo "  Press Enter when ready..."
read -r

# Step 4: Test — list devices
echo "Step 4: Checking for Screen Time data..."
echo "  Looking for synced devices..."
$AW_CMD devices --paths 2>&1 || echo "  ⚠ Could not list devices. Check Full Disk Access."
echo ""

# Step 5: Preview events
echo "Step 5: Previewing recent Screen Time data..."
$AW_CMD events preview --since 24h 2>&1 | head -20 || echo "  ⚠ No events found. Make sure Screen Time is enabled and syncing."
echo ""

# Step 6: Do the actual import
echo "Step 6: Importing into ActivityWatch..."
$AW_CMD events import --since 7d 2>&1 || echo "  ⚠ Import failed. Is ActivityWatch running on http://localhost:5600?"
echo ""

# Step 7: Create launchd plist for hourly automation
echo "Step 7: Creating launchd job (runs every hour)..."
mkdir -p "$LOG_DIR"

# We need a wrapper script since launchd can't run 'uv run' directly with args
WRAPPER="$INSTALL_DIR/run-import.sh"
cat > "$WRAPPER" << 'INNEREOF'
#!/bin/bash
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$HOME/.local/bin"
INNEREOF
echo "cd \"$INSTALL_DIR\" && uv run aw-import-screentime events import --since 2h" >> "$WRAPPER"
chmod +x "$WRAPPER"

cat > "$PLIST_PATH" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${PLIST_NAME}</string>

    <key>ProgramArguments</key>
    <array>
        <string>${WRAPPER}</string>
    </array>

    <key>StartInterval</key>
    <integer>3600</integer>

    <key>RunAtLoad</key>
    <true/>

    <key>StandardOutPath</key>
    <string>${LOG_DIR}/screentime-import.log</string>

    <key>StandardErrorPath</key>
    <string>${LOG_DIR}/screentime-import-error.log</string>
</dict>
</plist>
EOF

echo "  ✓ Created $PLIST_PATH"

# Step 8: Load the job
echo "Step 8: Loading launchd job..."
launchctl unload "$PLIST_PATH" 2>/dev/null || true
launchctl load "$PLIST_PATH"
echo "  ✓ Loaded. Will run every hour and at login."
echo ""

echo "=========================================="
echo "  Setup Complete!"
echo "=========================================="
echo ""
echo "  • Screen Time data will sync to ActivityWatch every hour"
echo "  • Logs: $LOG_DIR/"
echo "  • Manual import: cd $INSTALL_DIR && uv run aw-import-screentime events import --since 24h"
echo "  • Stop automation: launchctl unload $PLIST_PATH"
echo "  • Check status: launchctl list | grep screentime"
echo ""
echo "  Next: Open TimeBudget on your iPhone."
echo "  The app will auto-discover the aw-import-screentime bucket"
echo "  and show your iPhone Screen Time data alongside Mac desk time."
echo ""
