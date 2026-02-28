# VSCode4Everyone

A portable VSCode distribution with pre-configured AI agents and settings.

## Overview

This project packages Visual Studio Code into a self-contained installer with embedded configurations, AI agents, and extensions. The result is a single-file installer that can be distributed easily.

Both Windows and Mac/Linux versions provide **functionally equivalent** installers that are adapted to each platform's conventions and best practices.

### Platform Comparison

| Feature | Windows | Mac/Linux |
|---------|---------|-----------|
| **Archive format** | .zip | .zip (macOS) / .tar.gz (Linux) |
| **Install location** | `C:\dev\tools\vscode4everyone` | `~/Applications/vscode4everyone` (macOS)<br>`~/.local/share/vscode4everyone` (Linux) |
| **Launcher type** | VBS + CMD (no console window) | Bash script |
| **Desktop integration** | Desktop shortcut + taskbar pin | .desktop file (Linux) / .app launcher (macOS) |
| **Command-line access** | `vs-4everyone.cmd` | Symlink in `~/.local/bin/vs-4everyone` |
| **VSCode binary** | `Code.exe` | `Visual Studio Code.app/...` (macOS)<br>`bin/code` (Linux) |

**What's the same across all platforms:**
- ✓ Embedded base64-encoded VSCode archive
- ✓ Embedded agents (auto-installed to workspace)
- ✓ Embedded settings.json (auto-configured)
- ✓ Creates portable installation with data directory
- ✓ Sets up workspace at `Documents/vscode4everyone`
- ✓ Creates launcher shortcuts
- ✓ Single-file, self-contained installer
- ✓ Backup and reinstall capability with force flag

## Setup

Before building the installer, you need to place the required files in the appropriate directories:

### 1. Add VS Code Installer

Download and place the VS Code installer archive in the `installers/` folder:

**Windows:**
- Download: `VSCode-win32-x64-{version}.zip`
- Place in: `installers/VSCode-win32-x64-{version}.zip`

**macOS:**
- Download: `VSCode-darwin-universal-{version}.zip`
- Place in: `installers/VSCode-darwin-universal-{version}.zip`

**Linux:**
- Download: `VSCode-linux-x64-{version}.tar.gz`
- Place in: `installers/VSCode-linux-x64-{version}.tar.gz`

### 2. Add Custom Agents

Place your custom AI agent files (`.agent.md` format) in the `agents/` folder:

```
agents/
├── YourCustomAgent.agent.md
├── AnotherAgent.agent.md
└── ...
```

These agents will be automatically embedded in the installer and deployed to the workspace during installation.

> **Note:** Once you've added files to the `agents/` or `installers/` folders, remove the `.gitkeep` file from those directories as it's no longer needed.

## Building the Installer

> **Note:** To build the Mac/Linux installer, you need to run `package.sh` on a Mac/Linux machine or use WSL (Windows Subsystem for Linux) on Windows. The Windows installer can only be built on Windows.

### Windows

Use PowerShell to create the Windows installer:

```powershell
powershell -ExecutionPolicy Bypass -File .\package.ps1
```

Or if you have the execution policy already set:

```powershell
.\package.ps1
```

Options:
- `-Force`: Remove existing dist directory before creating new installer

The script will:
1. Read the VSCode zip file from `installers\VSCode-win32-x64-{version}.zip`
2. Package the agents from the `agents\` directory
3. Embed the VSCode settings from `config\vscode-settings.json`
4. Create a self-extracting PowerShell installer in `dist\install-vscode4everyone.ps1`

#### Installing on Windows

Run the generated installer:

```powershell
powershell -ExecutionPolicy Bypass -File .\dist\install-vscode4everyone.ps1
```

Or if you have the execution policy already set:

```powershell
.\dist\install-vscode4everyone.ps1
```

Options:
- `-Force`: Backup existing installation and reinstall

The installer will:
- Extract VSCode to `c:\dev\tools\vscode4everyone`
- Configure portable mode with data directory
- Install AI agents to `%USERPROFILE%\Documents\vscode4everyone\.github\agents`
- Create desktop shortcut
- Create taskbar shortcut
- Create launcher scripts

### Mac/Linux

Use bash to create the Mac/Linux installer:

```bash
./package.sh
```

> **Note:** The `package.sh` script is already executable when cloned from the repository, so you can run it directly without needing to `chmod +x` it first.

Options:
- `-f` or `--force`: Remove existing dist directory before creating new installer

The script will:
1. Read the VSCode archive from `installers/` directory:
   - macOS: `VSCode-darwin-universal-{version}.zip`
   - Linux: `VSCode-linux-x64-{version}.tar.gz`
2. Package the agents from the `agents/` directory
3. Embed the VSCode settings from `config/vscode-settings.json`
4. Create a self-extracting bash installer in `dist/install-vscode4everyone.sh`

#### Installing on Mac/Linux

Run the installer:

```bash
./dist/install-vscode4everyone.sh
```

> **Note:** The generated installer is already executable, so you can run it directly without needing to `chmod +x` it first.

Options:
- `-f` or `--force`: Backup existing installation and reinstall

The installer will:
- Extract VSCode to:
  - macOS: `~/Applications/vscode4everyone`
  - Linux: `~/.local/share/vscode4everyone`
- Configure portable mode with data directory
- Install AI agents to `~/Documents/vscode4everyone/.github/agents`
- Create launcher script at `{install_dir}/bin/vs-4everyone`
- Create symlink in `~/.local/bin/` (if directory exists)
- Create desktop entry (Linux) or app launcher (macOS)

## Directory Structure

```
vscode4everyone/
├── package.ps1                    # Windows packaging script
├── package.sh                     # Mac/Linux packaging script
├── README.md                      # This file
├── agents/                        # AI agent definitions
│   ├── CodeQualityReviewer.agent.md
│   ├── DotNetUnitTestGenerator.agent.md
│   ├── HowToDocumentGenerator.agent.md
│   └── ...
├── config/
│   └── vscode-settings.json      # VSCode settings to embed
├── installers/                    # Place VSCode archives here
│   ├── VSCode-win32-x64-{version}.zip          # Windows
│   ├── VSCode-darwin-universal-{version}.zip   # macOS
│   └── VSCode-linux-x64-{version}.tar.gz       # Linux
└── dist/                          # Generated installers (created by package scripts)
    ├── install-vscode4everyone.ps1   # Windows installer (distribute to Windows users)
    └── install-vscode4everyone.sh    # Mac/Linux installer (distribute to Mac/Linux users)
```

## What Gets Distributed

After running the packaging scripts, you'll have single-file, self-contained installers in the `dist/` directory:

- **`dist/install-vscode4everyone.ps1`** - Give this to Windows users
- **`dist/install-vscode4everyone.sh`** - Give this to Mac/Linux users

Each installer contains:
- Complete VSCode installation (base64-embedded)
- All AI agents from the `agents/` directory
- VSCode settings from `config/vscode-settings.json`
- Platform-specific launcher scripts and shortcuts

End users only need the single installer file - no additional downloads required.

## Prerequisites

### For Building

**Windows:**
- PowerShell 5.1 or later
- VSCode zip file in `installers/` directory

**Mac/Linux:**
- bash
- zip utility
- base64 utility (usually pre-installed)
- VSCode archive in `installers/` directory

### For Installing

**Windows:**
- PowerShell 5.1 or later
- Windows 7 or later

**Mac/Linux:**
- bash
- unzip utility (macOS/Linux with zip archives)
- tar utility (Linux with tar.gz archives)

## Launching VSCode4Everyone

After installation:

**Windows:**
- Double-click the desktop shortcut "VS Code 4 Everyone"
- Click the taskbar icon
- Run `c:\dev\tools\vscode4everyone\bin\vs-4everyone.cmd`

**macOS:**
- Open VSCode4Everyone from Applications folder
- Run `vs-4everyone` from terminal

**Linux:**
- Launch from application menu: "VS Code 4 Everyone"
- Run `vs-4everyone` from terminal

## Customization

### Adding/Modifying Agents

Add or edit `.agent.md` files in the `agents/` directory, then rebuild the installer.

### Changing Settings

Edit `config/vscode-settings.json`, then rebuild the installer.

### Updating VSCode Version

1. Download the appropriate VSCode archive for your platform
2. Place it in the `installers/` directory
3. Update the version number in the packaging script (`package.ps1` or `package.sh`)
4. Rebuild the installer

## Notes

- The installer creates a **portable** installation, meaning all user data and extensions are stored within the installation directory or the workspace directory
- The workspace directory is set to `Documents/vscode4everyone` by default
- AI agents are installed to `.github/agents` within the workspace
- The generated installers are self-contained and can be distributed as single files

## License

This packaging project is provided as-is. Visual Studio Code is licensed under the MIT License by Microsoft Corporation.
