# UpdateManager.ps1
# Windows Update control script with interactive menu
# Run as Administrator

# =======================
# Auto Elevation Section
# =======================
function Ensure-RunAsAdmin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host "⚠️  Script is not running as Administrator. Requesting elevation..." -ForegroundColor Yellow
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "powershell.exe"
        $psi.Arguments = "-ExecutionPolicy Bypass -File `"$PSCommandPath`""
        $psi.Verb = "runas"
        try {
            [System.Diagnostics.Process]::Start($psi) | Out-Null
        } catch {
            Write-Host "❌ User cancelled UAC prompt." -ForegroundColor Red
        }
        exit
    }
}
Ensure-RunAsAdmin
# =======================

function Set-RegistryValue {
    param(
        [string]$Path,
        [string]$Name,
        [object]$Value
    )
    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }
    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Force
}

function Set-ManualUpdate {
    Write-Host "`nSwitching to MANUAL mode (disable auto update)..." -ForegroundColor Yellow
    Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" "NoAutoUpdate" 1
    gpupdate /force | Out-Null
    Write-Host "✅ Windows Update is now MANUAL" -ForegroundColor Green
}

function Set-AutoUpdate {
    Write-Host "`nSwitching to AUTO mode (restore default)..." -ForegroundColor Yellow
    Remove-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Recurse -ErrorAction SilentlyContinue
    gpupdate /force | Out-Null
    Write-Host "✅ Windows Update is now AUTO" -ForegroundColor Green
}

function Set-PauseUpdate {
    param([int]$Days)
    Write-Host "`nPausing updates for $Days days..." -ForegroundColor Yellow

    $today = (Get-Date).ToString("yyyy-MM-dd")
    $resume = (Get-Date).AddDays($Days).ToString("yyyy-MM-dd")

    Set-RegistryValue "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" "PauseUpdatesStartTime" $today
    Set-RegistryValue "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" "PauseUpdatesExpiryTime" $resume
    Set-RegistryValue "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" "PauseFeatureUpdatesStartTime" $today
    Set-RegistryValue "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" "PauseFeatureUpdatesEndTime" $resume
    Set-RegistryValue "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" "PauseQualityUpdatesStartTime" $today
    Set-RegistryValue "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" "PauseQualityUpdatesEndTime" $resume

    gpupdate /force | Out-Null
    Write-Host "✅ Updates are paused until $resume" -ForegroundColor Green
}

function Reset-UpdatePolicy {
    Write-Host "`nRestoring default update policy..." -ForegroundColor Yellow
    Remove-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Recurse -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" `
        -Name PauseUpdatesStartTime,PauseUpdatesExpiryTime,PauseFeatureUpdatesStartTime,PauseFeatureUpdatesEndTime,PauseQualityUpdatesStartTime,PauseQualityUpdatesEndTime `
        -ErrorAction SilentlyContinue

    gpupdate /force | Out-Null
    Write-Host "✅ Windows Update policy restored to DEFAULT" -ForegroundColor Green
}

function Get-UpdateStatus {
    Write-Host "`n===== Windows Update Status =====" -ForegroundColor Cyan

    $manual = Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -ErrorAction SilentlyContinue
    if ($manual.NoAutoUpdate -eq 1) {
        Write-Host "Mode: MANUAL (auto updates disabled)" -ForegroundColor Yellow
    } else {
        Write-Host "Mode: AUTO (default behavior)" -ForegroundColor Green
    }

    $ux = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -ErrorAction SilentlyContinue
    if ($ux.PauseUpdatesExpiryTime) {
        $expiry = Get-Date $ux.PauseUpdatesExpiryTime
        if ($expiry -gt (Get-Date)) {
            Write-Host "Pause: ACTIVE until $expiry" -ForegroundColor Magenta
        } else {
            Write-Host "Pause: expired on $expiry" -ForegroundColor Gray
        }
    } else {
        Write-Host "Pause: NOT set" -ForegroundColor Gray
    }

    # Service check
    $svc = Get-Service -Name wuauserv -ErrorAction SilentlyContinue
    if ($svc) {
        Write-Host "Service 'wuauserv': $($svc.Status)" -ForegroundColor Cyan
    } else {
        Write-Host "Service 'wuauserv': not found" -ForegroundColor Red
    }

    Write-Host "=================================" -ForegroundColor Cyan
}

function Show-Menu {
    Clear-Host
    Write-Host "========= Windows Update Manager =========" -ForegroundColor Cyan
    Write-Host "1. Manual Update (disable auto update)"
    Write-Host "2. Auto Update (restore default)"
    Write-Host "3. Pause Updates (enter number of days)"
    Write-Host "4. Reset (clear all policies)"
    Write-Host "5. Status (check current state)"
    Write-Host "=========================================="
}

do {
    Show-Menu
    $choice = Read-Host "Select option (1-5, q to quit)"

    switch ($choice) {
        "1" { Set-ManualUpdate }
        "2" { Set-AutoUpdate }
        "3" { 
            $days = Read-Host "Enter number of days to pause (7, 30, 9999)"
            if ($days -match '^\d+$') {
                Set-PauseUpdate -Days ([int]$days)
            } else {
                Write-Host "❌ Invalid input, must be a number" -ForegroundColor Red
            }
        }
        "4" { Reset-UpdatePolicy }
        "5" { Get-UpdateStatus }
        "q" { Write-Host "Exit script." -ForegroundColor Gray }
        default { Write-Host "❌ Invalid choice, enter 1-5 or q" -ForegroundColor Red }
    }

    if ($choice -ne "q") {
        Pause
    }

} while ($choice -ne "q")
