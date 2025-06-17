# Enable Hyper-V, install chocolatey and other tools

# Function to check and elevate if not running as admin
function Ensure-Admin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $adminRole = [Security.Principal.WindowsPrincipal]::new($currentUser)
    if (-not $adminRole.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host "Restarting with Administrator privileges..."
        Start-Process powershell "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
        exit
    }
}

# Disable AutoPlay
function Disable-AutoPlay {
    Write-Host "Disabling AutoPlay..." -ForegroundColor Cyan

    try {
        # Disable AutoPlay for all drives
        New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers" -Force | Out-Null
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers" `
                         -Name "DisableAutoplay" -Value 1

        # Apply to all drives(FF = 255)
        New-Item -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Force | Out-Null
        Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" `
                         -Name "NoDriveTypeAutoRun" -Value 255

        Write-Host "AutoPlay disabled successfully." -ForegroundColor Green
    } catch {
        Write-Warning "Failed to disable AutoPlay: $_"
    }
}

# Disable delivery optimization
function Disable-DeliveryOptimization {
    Write-Host "Disabling Delivery Optimization..." -ForegroundColor Cyan

    try {
        # Stop the service if running
        Stop-Service -Name DoSvc -Force -ErrorAction SilentlyContinue

        # Set the service to Disabled
        Set-Service -Name DoSvc -StartupType Disabled -ErrorAction SilentlyContinue

        # Policy-based registry setting
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" -Force | Out-Null
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" -Name "DODownloadMode" -Value 0

        # Also set runtime config (optional redundancy)
        New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" -Force | Out-Null
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" -Name "DODownloadMode" -Value 0

        Write-Host "Delivery Optimization disabled successfully." -ForegroundColor Green
    } catch {
        Write-Warning "Failed to disable Delivery Optimization: $_"
    }
}

# Confirm with user before proceeding
function Confirm-Install {
    Add-Type -AssemblyName System.Windows.Forms
    $msgBox = [System.Windows.Forms.MessageBox]::Show(
        "Do you want to install common tools (Firefox, Chromium, Cmder, gsudo, etc.)?",
        "Batch Installer",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )
    if ($msgBox -ne [System.Windows.Forms.DialogResult]::Yes) {
        Write-Host "Installation cancelled by user."
        exit
    }
}

# Install Chocolatey if missing
function Install-Choco {
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Host "Installing Chocolatey..."
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    } else {
        Write-Host "Chocolatey is already installed."
    }
}

# Install software packages
function Install-Tools {
    choco upgrade chocolatey -y
    $packages = @('firefox', 'chromium', 'cmder', 'gsudo', 'peazip', 'notepad3', 'vscodium', 'busybox', 'vlc')
    choco install $packages -y
    Write-Host "Finished installing packages."

    # Configure gsudo to have path precedence (so 'sudo' starts gsudo instead of Microsoft's sudo)
    gsudo config PathPrecedence true

    # Return whether cmder was installed by checking if cmder.exe exists in PATH
    return (Get-Command cmder.exe -ErrorAction SilentlyContinue) -ne $null
}

# Enable Hyper-V and related features if not running inside a VM
function Enable-HyperV-IfNotVM {
    Add-Type -AssemblyName PresentationFramework

    $system = Get-CimInstance Win32_ComputerSystem
    $model = $system.Model
    $manufacturer = $system.Manufacturer

    $isVM = $model -match "Virtual|VMware|VirtualBox|QEMU|HVM" -or `
            $manufacturer -match "Microsoft|VMware|innotek|Xen|QEMU"

    if ($isVM) {
        Write-Host "Virtual machine detected: $model ($manufacturer)"
        return
    }

    Write-Host "Physical machine detected: $model ($manufacturer)"

    # Ask user whether to enable Hyper-V
    $result = [System.Windows.MessageBox]::Show(
        "Do you want to enable Hyper-V and related virtualization features?",
        "Enable Hyper-V",
        'YesNo',
        'Question'
    )

    if ($result -eq 'Yes') {
        Write-Host "Enabling Hyper-V components..."

        Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -All -NoRestart
        Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -All -NoRestart
        Enable-WindowsOptionalFeature -Online -FeatureName HypervisorPlatform -All -NoRestart

        Write-Host "Hyper-V features enabled. Please restart to take effect."
    } else {
        Write-Host "User declined Hyper-V installation."
    }
}

# Add Cmder profile to Windows Terminal settings.json
function Add-CmderProfileToWT {
    # Locate cmder.exe from PATH
    $cmderExe = Get-Command cmder.exe -ErrorAction SilentlyContinue
    if (-not $cmderExe) {
        Write-Warning "cmder.exe not found in PATH. Is Cmder installed?"
        return
    }

    # Resolve key paths
    $cmderPath = Split-Path -Parent $cmderExe.Path
    $initBat = Join-Path $cmderPath 'vendor\init.bat'
    $iconPath = Join-Path $cmderPath 'icons\cmder.ico'

    # Detect correct settings.json path for Windows Terminal
    $storeJsonPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    $nonStoreJsonPath = "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"

    if (Test-Path $storeJsonPath) {
        $jsonPath = $storeJsonPath
    } elseif (Test-Path $nonStoreJsonPath) {
        $jsonPath = $nonStoreJsonPath
    } else {
        Write-Warning "Windows Terminal settings.json not found. Please open Windows Terminal once before running this script."
        return
    }

    # Load settings.json content and parse as JSON
    $json = Get-Content $jsonPath -Raw | ConvertFrom-Json

    # Get the profiles list
    $profileList = $json.profiles.list

    # Find the index of the existing Cmder profile (if any)
    $existingIndex = -1
    for ($i = 0; $i -lt $profileList.Count; $i++) {
        if ($profileList[$i].name -eq "Cmder") {
            $existingIndex = $i
            break
        }
    }

    if ($existingIndex -ge 0) {
        $profileGuid = $profileList[$existingIndex].guid
        Write-Host "Cmder profile already exists. It will be overwritten."
        # Remove the existing Cmder profile by filtering the list
        $json.profiles.list = $profileList | Where-Object { $_.name -ne "Cmder" }
    } else {
        $profileGuid = "{" + [guid]::NewGuid().ToString() + "}"
        Write-Host "Creating new Cmder profile."
    }

    # Construct the Cmder profile object
    $cmderProfile = @{
        guid = $profileGuid
        name = "Cmder"
        commandline = "$env:SystemRoot\System32\cmd.exe /k `"$initBat`""
        startingDirectory = "%USERPROFILE%"
        icon = $iconPath
        hidden = $false
    }

    # Add the Cmder profile to the profiles list
    $json.profiles.list += $cmderProfile

    # Ensure defaults object exists to avoid errors
    if (-not $json.profiles.defaults) {
        $json.profiles.defaults = @{}
    }

    # Set Cmder profile as the default profile
    $json.defaultProfile = $cmderProfile.guid

    # Save the updated JSON back to settings.json file
    $json | ConvertTo-Json -Depth 5 | Set-Content -Path $jsonPath -Encoding UTF8

    Write-Host "Cmder profile added, set as default."
}

### MAIN SCRIPT EXECUTION ###

Ensure-Admin

Disable-AutoPlay

Disable-DeliveryOptimization

Enable-HyperV-IfNotVM

Confirm-Install

Install-Choco

$cmderInstalled = Install-Tools

if ($cmderInstalled) {
    Add-CmderProfileToWT
} else {
    Write-Host "Cmder was not installed, skipping Windows Terminal profile configuration."
}
