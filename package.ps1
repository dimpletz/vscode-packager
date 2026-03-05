# package.ps1
# Creates an installer script with embedded base64-encoded VSCode zip file

param(
    [switch]$Force
)

$ErrorActionPreference = "Stop"

# VSCode version to package
$vscodeVersion = "1.109.5"

# Get the VSCode zip file from installers directory
$zipPath = Join-Path $PSScriptRoot "installers\VSCode-win32-x64-$vscodeVersion.zip"

if (-not (Test-Path $zipPath)) {
    Write-Error "VSCode zip file not found at: $zipPath"
    exit 1
}

Write-Host "Reading VSCode zip file: $zipPath"
$zipBytes = [System.IO.File]::ReadAllBytes($zipPath)
$base64 = [System.Convert]::ToBase64String($zipBytes)

Write-Host "Zip file size: $($zipBytes.Length) bytes"
Write-Host "Base64 size: $($base64.Length) characters"

# Create a zip of the agents directory
$agentsDir = Join-Path $PSScriptRoot "agents"
$agentsZipPath = Join-Path $env:TEMP "vscode4everyone-agents.zip"

if (Test-Path $agentsDir) {
    Write-Host "`nCreating agents zip archive..."
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    
    # Remove existing temp zip if it exists
    if (Test-Path $agentsZipPath) {
        Remove-Item $agentsZipPath -Force
    }
    
    [System.IO.Compression.ZipFile]::CreateFromDirectory($agentsDir, $agentsZipPath)
    
    $agentsZipBytes = [System.IO.File]::ReadAllBytes($agentsZipPath)
    $agentsBase64 = [System.Convert]::ToBase64String($agentsZipBytes)
    
    Write-Host "Agents zip file size: $($agentsZipBytes.Length) bytes"
    Write-Host "Agents base64 size: $($agentsBase64.Length) characters"
    
    # Clean up temp zip
    Remove-Item $agentsZipPath -Force
} else {
    Write-Warning "Agents directory not found at: $agentsDir"
    $agentsBase64 = ""
}

# Create the installer script
$installerScript = @'
# install-vscode4everyone.ps1
# Auto-generated installer script with embedded VSCode

param(
    [switch]$Force
)

$ErrorActionPreference = "Stop"

Write-Host "VSCode4Everyone Installer" -ForegroundColor Cyan
Write-Host "=========================" -ForegroundColor Cyan

# Target installation directory
$installDir = "c:\dev\tools\vscode4everyone"

Write-Host "Installing to: $installDir"

# Handle existing installation with -Force flag
if (Test-Path $installDir) {
    if ($Force) {
        $dateStamp = Get-Date -Format "yyyyMMdd"
        $backupDir = "c:\dev\tools\vscode4everyone-$dateStamp"
        
        if (Test-Path $backupDir) {
            Write-Host "Backup directory already exists, deleting original installation..." -ForegroundColor Yellow
            Remove-Item $installDir -Recurse -Force
        } else {
            Write-Host "Backing up existing installation to: $backupDir" -ForegroundColor Yellow
            Rename-Item $installDir $backupDir
        }
    } else {
        Write-Warning "Installation directory already exists. Use -Force to backup and reinstall."
        exit 0
    }
}

# Create directory if it doesn't exist
if (-not (Test-Path $installDir)) {
    Write-Host "Creating installation directory..."
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null
}

# Embedded base64 VSCode zip data
$base64Data = @"
'@ + "`r`n$base64`r`n" + @'
"@

Write-Host "Decoding embedded VSCode archive..."
$zipBytes = [System.Convert]::FromBase64String($base64Data)

# Create temporary zip file
$tempZip = Join-Path $env:TEMP "vscode4everyone-temp.zip"
Write-Host "Writing temporary zip file..."
[System.IO.File]::WriteAllBytes($tempZip, $zipBytes)

try {
    Write-Host "Extracting VSCode to $installDir..."
    
    # Extract the zip file
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($tempZip, $installDir, $true)
    
    Write-Host "Installation completed successfully!" -ForegroundColor Green
    Write-Host "VSCode installed to: $installDir" -ForegroundColor Green
}
catch {
    Write-Error "Failed to extract VSCode: $_"
    exit 1
}
finally {
    # Clean up temporary file
    if (Test-Path $tempZip) {
        Remove-Item $tempZip -Force
    }
}

# Create launcher script
Write-Host "`nCreating launcher scripts..."
$binDir = Join-Path $installDir "bin"
if (-not (Test-Path $binDir)) {
    New-Item -ItemType Directory -Path $binDir -Force | Out-Null
}

# Create VBS launcher (no console window)
$vbsLauncherPath = Join-Path $binDir "vs-invoker.vbs"
$vbsLauncherContent = @"
Set WshShell = CreateObject("WScript.Shell")
Set objFSO = CreateObject("Scripting.FileSystemObject")

' Get the script directory
strScriptPath = objFSO.GetParentFolderName(WScript.ScriptFullName)
strCodeCmd = objFSO.BuildPath(strScriptPath, "code.cmd")
strWorkspace = WshShell.ExpandEnvironmentStrings("%USERPROFILE%\Documents\vscode4everyone")

' Create workspace directory if it doesn't exist
If Not objFSO.FolderExists(strWorkspace) Then
    objFSO.CreateFolder(strWorkspace)
End If

' Switch to workspace directory and launch VSCode
WshShell.CurrentDirectory = strWorkspace
strCommand = Chr(34) & strCodeCmd & Chr(34) & " chat --maximize"
WshShell.Run strCommand, 0, False
"@
[System.IO.File]::WriteAllText($vbsLauncherPath, $vbsLauncherContent)
Write-Host "Created: $vbsLauncherPath" -ForegroundColor Green

# Create CMD wrapper that calls the VBS
$vsCmdPath = Join-Path $binDir "vs-4everyone.cmd"
$vsCmdContent = @"
@echo off
wscript.exe "%~dp0vs-invoker.vbs"
"@
[System.IO.File]::WriteAllText($vsCmdPath, $vsCmdContent)
Write-Host "Created: $vsCmdPath" -ForegroundColor Green

# Install agents if included
$agentsBase64Data = @"
'@ + "`r`n$agentsBase64`r`n" + @'
"@

if ($agentsBase64Data.Trim() -ne "") {
    Write-Host "`nInstalling agents..."
    
    # Target directory for agents
    $agentsInstallDir = Join-Path $env:USERPROFILE "Documents\vscode4everyone\.github\agents"
    Write-Host "Installing agents to: $agentsInstallDir"
    
    # Create directory if it doesn't exist
    if (-not (Test-Path $agentsInstallDir)) {
        Write-Host "Creating agents directory..."
        New-Item -ItemType Directory -Path $agentsInstallDir -Force | Out-Null
    }
    
    # Decode agents zip
    $agentsZipBytes = [System.Convert]::FromBase64String($agentsBase64Data)
    $tempAgentsZip = Join-Path $env:TEMP "vscode4everyone-agents-temp.zip"
    [System.IO.File]::WriteAllBytes($tempAgentsZip, $agentsZipBytes)
    
    try {
        Write-Host "Extracting agents..."
        [System.IO.Compression.ZipFile]::ExtractToDirectory($tempAgentsZip, $agentsInstallDir, $true)
        Write-Host "Agents installed successfully!" -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed to extract agents: $_"
    }
    finally {
        # Clean up temporary file
        if (Test-Path $tempAgentsZip) {
            Remove-Item $tempAgentsZip -Force
        }
    }
}

Write-Host "`nInstallation complete!" -ForegroundColor Cyan
'@

# Create dist directory if it doesn't exist
$distDir = Join-Path $PSScriptRoot "dist"

if ($Force -and (Test-Path $distDir)) {
    Write-Host "`n-Force specified: Removing existing dist directory..." -ForegroundColor Yellow
    Remove-Item $distDir -Recurse -Force
}

if (-not (Test-Path $distDir)) {
    Write-Host "Creating dist directory..."
    New-Item -ItemType Directory -Path $distDir -Force | Out-Null
}

# Write the installer script
$installerPath = Join-Path $distDir "install-vscode4everyone.ps1"
$installerScript | Out-File -FilePath $installerPath -Encoding UTF8

Write-Host "`nInstaller script created successfully!" -ForegroundColor Green
Write-Host "Output: $installerPath" -ForegroundColor Green
Write-Host "`nTo install VSCode4Everyone, run:" -ForegroundColor Yellow
Write-Host "  .\install-vscode4everyone.ps1" -ForegroundColor Yellow
