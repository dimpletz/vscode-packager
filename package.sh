#!/bin/bash
# package.sh
# Creates an installer script with embedded base64-encoded VSCode archive

set -e

# Parse command line arguments
FORCE=0
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--force)
            FORCE=1
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Detect OS type
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS_TYPE="darwin"
    VSCODE_VERSION="1.109.5"
    ARCHIVE_NAME="VSCode-darwin-universal-${VSCODE_VERSION}.zip"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS_TYPE="linux"
    VSCODE_VERSION="1.109.5"
    ARCHIVE_NAME="VSCode-linux-x64-${VSCODE_VERSION}.tar.gz"
else
    echo "Unsupported OS type: $OSTYPE"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Get the VSCode archive from installers directory
ARCHIVE_PATH="${SCRIPT_DIR}/installers/${ARCHIVE_NAME}"

if [[ ! -f "$ARCHIVE_PATH" ]]; then
    echo "Error: VSCode archive not found at: $ARCHIVE_PATH"
    exit 1
fi

echo "Reading VSCode archive: $ARCHIVE_PATH"
BASE64_DATA=$(base64 < "$ARCHIVE_PATH")
ARCHIVE_SIZE=$(stat -f%z "$ARCHIVE_PATH" 2>/dev/null || stat -c%s "$ARCHIVE_PATH" 2>/dev/null)

echo "Archive size: $ARCHIVE_SIZE bytes"
echo "Base64 size: ${#BASE64_DATA} characters"

# Create a zip of the agents directory
AGENTS_DIR="${SCRIPT_DIR}/agents"
AGENTS_ZIP_PATH="/tmp/vscode4everyone-agents.zip"

if [[ -d "$AGENTS_DIR" ]]; then
    echo ""
    echo "Creating agents zip archive..."
    
    # Remove existing temp zip if it exists
    rm -f "$AGENTS_ZIP_PATH"
    
    # Create zip from agents directory
    (cd "$AGENTS_DIR" && zip -r "$AGENTS_ZIP_PATH" .)
    
    AGENTS_BASE64=$(base64 < "$AGENTS_ZIP_PATH")
    AGENTS_SIZE=$(stat -f%z "$AGENTS_ZIP_PATH" 2>/dev/null || stat -c%s "$AGENTS_ZIP_PATH" 2>/dev/null)
    
    echo "Agents zip file size: $AGENTS_SIZE bytes"
    echo "Agents base64 size: ${#AGENTS_BASE64} characters"
    
    # Clean up temp zip
    rm -f "$AGENTS_ZIP_PATH"
else
    echo "Warning: Agents directory not found at: $AGENTS_DIR"
    AGENTS_BASE64=""
fi

# Read VSCode settings.json
SETTINGS_JSON_PATH="${SCRIPT_DIR}/config/vscode-settings.json"
if [[ -f "$SETTINGS_JSON_PATH" ]]; then
    echo ""
    echo "Reading VSCode settings..."
    SETTINGS_JSON_CONTENT=$(cat "$SETTINGS_JSON_PATH")
    echo "Settings file size: ${#SETTINGS_JSON_CONTENT} characters"
else
    echo "Warning: VSCode settings file not found at: $SETTINGS_JSON_PATH"
    SETTINGS_JSON_CONTENT="{}"
fi

# Create the installer script
DIST_DIR="${SCRIPT_DIR}/dist"

if [[ $FORCE -eq 1 ]] && [[ -d "$DIST_DIR" ]]; then
    echo ""
    echo "-Force specified: Removing existing dist directory..."
    rm -rf "$DIST_DIR"
fi

if [[ ! -d "$DIST_DIR" ]]; then
    echo "Creating dist directory..."
    mkdir -p "$DIST_DIR"
fi

INSTALLER_PATH="${DIST_DIR}/install-vscode4everyone.sh"

# Generate the installer script
cat > "$INSTALLER_PATH" << 'EOF_INSTALLER_START'
#!/bin/bash
# install-vscode4everyone.sh
# Auto-generated installer script with embedded VSCode

set -e

# Parse command line arguments
FORCE=0
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--force)
            FORCE=1
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo "============================="
echo "VSCode4Everyone Installer"
echo "============================="
echo ""

# Detect OS type
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS_TYPE="darwin"
    INSTALL_DIR="$HOME/Applications/vscode4everyone"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS_TYPE="linux"
    INSTALL_DIR="$HOME/.local/share/vscode4everyone"
else
    echo "Unsupported OS type: $OSTYPE"
    exit 1
fi

echo "Installing to: $INSTALL_DIR"

# Handle existing installation with -Force flag
if [[ -d "$INSTALL_DIR" ]]; then
    if [[ $FORCE -eq 1 ]]; then
        DATE_STAMP=$(date +%Y%m%d)
        BACKUP_DIR="${INSTALL_DIR}-${DATE_STAMP}"
        
        if [[ -d "$BACKUP_DIR" ]]; then
            echo "Backup directory already exists, deleting original installation..."
            rm -rf "$INSTALL_DIR"
        else
            echo "Backing up existing installation to: $BACKUP_DIR"
            mv "$INSTALL_DIR" "$BACKUP_DIR"
        fi
    else
        echo "Warning: Installation directory already exists. Use -f or --force to backup and reinstall."
        exit 0
    fi
fi

# Create directory if it doesn't exist
if [[ ! -d "$INSTALL_DIR" ]]; then
    echo "Creating installation directory..."
    mkdir -p "$INSTALL_DIR"
fi

# Embedded base64 VSCode archive data
read -r -d '' BASE64_DATA << 'EOF_BASE64' || true
EOF_INSTALLER_START

# Append the base64 data
echo "$BASE64_DATA" >> "$INSTALLER_PATH"

# Continue the installer script
cat >> "$INSTALLER_PATH" << 'EOF_INSTALLER_MID'
EOF_BASE64

echo "Decoding embedded VSCode archive..."

# Create temporary file
TEMP_ARCHIVE="/tmp/vscode4everyone-temp-$$.archive"
echo "Writing temporary archive file..."
echo "$BASE64_DATA" | base64 -d > "$TEMP_ARCHIVE"

# Extract based on OS type
echo "Extracting VSCode to $INSTALL_DIR..."

if [[ "$OS_TYPE" == "darwin" ]]; then
    # macOS: extract zip
    unzip -q "$TEMP_ARCHIVE" -d "$INSTALL_DIR"
elif [[ "$OS_TYPE" == "linux" ]]; then
    # Linux: extract tar.gz
    tar -xzf "$TEMP_ARCHIVE" -C "$INSTALL_DIR" --strip-components=1
fi

# Clean up temporary file
rm -f "$TEMP_ARCHIVE"

echo "Installation completed successfully!"

# Create data directory for portable mode
echo ""
echo "Creating data directory for portable mode..."
DATA_DIR="${INSTALL_DIR}/data"
if [[ ! -d "$DATA_DIR" ]]; then
    mkdir -p "$DATA_DIR"
    echo "Created: $DATA_DIR"
fi

# Create User settings directory and settings.json
echo ""
echo "Configuring VSCode settings..."
USER_DATA_DIR="${DATA_DIR}/user-data/User"
if [[ ! -d "$USER_DATA_DIR" ]]; then
    mkdir -p "$USER_DATA_DIR"
fi

# Embedded VSCode settings.json content
read -r -d '' SETTINGS_JSON_CONTENT << 'EOF_SETTINGS' || true
EOF_INSTALLER_MID

# Append settings JSON
echo "$SETTINGS_JSON_CONTENT" >> "$INSTALLER_PATH"

# Continue the installer script
cat >> "$INSTALLER_PATH" << 'EOF_INSTALLER_MID2'
EOF_SETTINGS

SETTINGS_JSON_PATH="${USER_DATA_DIR}/settings.json"
echo "$SETTINGS_JSON_CONTENT" > "$SETTINGS_JSON_PATH"
echo "Created: $SETTINGS_JSON_PATH"

# Create launcher script
echo ""
echo "Creating launcher script..."
BIN_DIR="${INSTALL_DIR}/bin"
mkdir -p "$BIN_DIR"

# Determine VSCode binary path based on OS
if [[ "$OS_TYPE" == "darwin" ]]; then
    VSCODE_BIN="${INSTALL_DIR}/Visual Studio Code.app/Contents/Resources/app/bin/code"
else
    VSCODE_BIN="${INSTALL_DIR}/bin/code"
fi

# Create launcher script
LAUNCHER_PATH="${BIN_DIR}/vs-4everyone"
cat > "$LAUNCHER_PATH" << 'EOF_LAUNCHER'
#!/bin/bash
# VSCode4Everyone Launcher

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$(dirname "$SCRIPT_DIR")"

# Determine VSCode binary path based on OS
if [[ "$OSTYPE" == "darwin"* ]]; then
    VSCODE_BIN="${INSTALL_DIR}/Visual Studio Code.app/Contents/Resources/app/bin/code"
else
    VSCODE_BIN="${INSTALL_DIR}/bin/code"
fi

# Workspace directory
WORKSPACE="$HOME/Documents/vscode4everyone"

# Create workspace directory if it doesn't exist
if [[ ! -d "$WORKSPACE" ]]; then
    mkdir -p "$WORKSPACE"
fi

# Launch VSCode with chat maximized
cd "$WORKSPACE"
"$VSCODE_BIN" chat --maximize "$@" &
EOF_LAUNCHER

chmod +x "$LAUNCHER_PATH"
echo "Created: $LAUNCHER_PATH"

# Create symlink in user's local bin (if it exists)
LOCAL_BIN="$HOME/.local/bin"
if [[ -d "$LOCAL_BIN" ]]; then
    echo ""
    echo "Creating symlink in $LOCAL_BIN..."
    ln -sf "$LAUNCHER_PATH" "${LOCAL_BIN}/vs-4everyone"
    echo "Created symlink: ${LOCAL_BIN}/vs-4everyone"
    echo "You can now run 'vs-4everyone' from anywhere (if ~/.local/bin is in your PATH)"
fi

# Create desktop entry for Linux
if [[ "$OS_TYPE" == "linux" ]]; then
    echo ""
    echo "Creating desktop entry..."
    DESKTOP_DIR="$HOME/.local/share/applications"
    mkdir -p "$DESKTOP_DIR"
    
    DESKTOP_FILE="${DESKTOP_DIR}/vscode4everyone.desktop"
    cat > "$DESKTOP_FILE" << EOF_DESKTOP
[Desktop Entry]
Version=1.0
Type=Application
Name=VS Code 4 Everyone
Comment=Portable VSCode with AI Agents
Exec=${LAUNCHER_PATH}
Icon=${INSTALL_DIR}/resources/app/resources/linux/code.png
Terminal=false
Categories=Development;IDE;
StartupWMClass=Code
EOF_DESKTOP
    
    chmod +x "$DESKTOP_FILE"
    echo "Created: $DESKTOP_FILE"
fi

# Create macOS app alias
if [[ "$OS_TYPE" == "darwin" ]]; then
    echo ""
    echo "Creating macOS application launcher..."
    APPS_DIR="$HOME/Applications"
    mkdir -p "$APPS_DIR"
    
    # Create a simple launcher app using osascript
    APP_PATH="${APPS_DIR}/VSCode4Everyone.app"
    mkdir -p "${APP_PATH}/Contents/MacOS"
    
    APP_SCRIPT="${APP_PATH}/Contents/MacOS/VSCode4Everyone"
    cat > "$APP_SCRIPT" << EOF_MAC_APP
#!/bin/bash
"${LAUNCHER_PATH}"
EOF_MAC_APP
    
    chmod +x "$APP_SCRIPT"
    
    # Create Info.plist
    cat > "${APP_PATH}/Contents/Info.plist" << EOF_PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>VSCode4Everyone</string>
    <key>CFBundleIconFile</key>
    <string>icon</string>
    <key>CFBundleIdentifier</key>
    <string>com.vscode4everyone.app</string>
    <key>CFBundleName</key>
    <string>VSCode4Everyone</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
</dict>
</plist>
EOF_PLIST
    
    echo "Created: $APP_PATH"
fi

# Install agents if included
read -r -d '' AGENTS_BASE64_DATA << 'EOF_AGENTS' || true
EOF_INSTALLER_MID2

# Append agents base64 data
echo "$AGENTS_BASE64" >> "$INSTALLER_PATH"

# Final part of the installer script
cat >> "$INSTALLER_PATH" << 'EOF_INSTALLER_END'
EOF_AGENTS

if [[ -n "${AGENTS_BASE64_DATA// /}" ]]; then
    echo ""
    echo "Installing agents..."
    
    # Target directory for agents
    AGENTS_INSTALL_DIR="$HOME/Documents/vscode4everyone/.github/agents"
    echo "Installing agents to: $AGENTS_INSTALL_DIR"
    
    # Create directory if it doesn't exist
    if [[ ! -d "$AGENTS_INSTALL_DIR" ]]; then
        echo "Creating agents directory..."
        mkdir -p "$AGENTS_INSTALL_DIR"
    fi
    
    # Decode agents zip
    TEMP_AGENTS_ZIP="/tmp/vscode4everyone-agents-temp-$$.zip"
    echo "$AGENTS_BASE64_DATA" | base64 -d > "$TEMP_AGENTS_ZIP"
    
    # Extract agents
    echo "Extracting agents..."
    unzip -q -o "$TEMP_AGENTS_ZIP" -d "$AGENTS_INSTALL_DIR"
    
    # Clean up temporary file
    rm -f "$TEMP_AGENTS_ZIP"
    
    echo "Agents installed successfully!"
fi

echo ""
echo "============================="
echo "Installation complete!"
echo "============================="
echo ""
if [[ "$OS_TYPE" == "darwin" ]]; then
    echo "You can launch VSCode4Everyone from:"
    echo "  - Applications folder: VSCode4Everyone.app"
    echo "  - Command line: vs-4everyone"
elif [[ "$OS_TYPE" == "linux" ]]; then
    echo "You can launch VSCode4Everyone from:"
    echo "  - Application menu: VS Code 4 Everyone"
    echo "  - Command line: vs-4everyone"
fi
echo ""
EOF_INSTALLER_END

# Make the installer executable
chmod +x "$INSTALLER_PATH"

echo ""
echo "Installer script created successfully!"
echo "Output: $INSTALLER_PATH"
echo ""
echo "To install VSCode4Everyone, run:"
echo "  bash $INSTALLER_PATH"
echo "  or"
echo "  chmod +x $INSTALLER_PATH && $INSTALLER_PATH"
