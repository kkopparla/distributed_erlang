<#
.SYNOPSIS
    Windows Defender Firewall Setup for Erlang Distributed Nodes
.DESCRIPTION
    Ensures TCP port 4369 (EPMD) and erl.exe / epmd.exe are allowed
    through the Windows Defender Firewall on both Private and Public profiles.
    Must be run in an Administrator PowerShell window.
#>

Write-Host "=== Erlang Distributed Firewall Configuration ===" -ForegroundColor Cyan

# Check Administrator privileges
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "This script requires Administrator privileges to configure Windows Firewall rules."
    Write-Warning "Please right-click PowerShell -> 'Run as Administrator', then run this script again."
    exit 1
}

# 1. Allow TCP 4369 (EPMD port)
$ruleName4369 = "Erlang EPMD (TCP 4369)"
$existing4369 = Get-NetFirewallRule -DisplayName $ruleName4369 -ErrorAction SilentlyContinue
if (-not $existing4369) {
    New-NetFirewallRule -DisplayName $ruleName4369 `
                        -Direction Inbound `
                        -Protocol TCP `
                        -LocalPort 4369 `
                        -Action Allow `
                        -Profile Any | Out-Null
    Write-Host "[+] Created firewall rule for EPMD (TCP 4369)" -ForegroundColor Green
} else {
    Write-Host "[OK] Firewall rule for EPMD (TCP 4369) already exists" -ForegroundColor Gray
}

# 2. Find and allow erl.exe and epmd.exe
$erlPath = (Get-Command erl -ErrorAction SilentlyContinue).Source
if ($erlPath) {
    $ruleNameErl = "Erlang BEAM (erl.exe)"
    $existingErl = Get-NetFirewallRule -DisplayName $ruleNameErl -ErrorAction SilentlyContinue
    if (-not $existingErl) {
        New-NetFirewallRule -DisplayName $ruleNameErl `
                            -Direction Inbound `
                            -Program $erlPath `
                            -Action Allow `
                            -Profile Any | Out-Null
        Write-Host "[+] Created firewall rule for: $erlPath" -ForegroundColor Green
    } else {
        Write-Host "[OK] Firewall rule for erl.exe already exists" -ForegroundColor Gray
    }

    # Locate epmd.exe in the same OTP installation
    $otpRoot = Split-Path (Split-Path $erlPath -Parent) -Parent
    $epmdFile = Get-ChildItem -Path $otpRoot -Filter "epmd.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($epmdFile) {
        $ruleNameEpmd = "Erlang EPMD Executable"
        $existingEpmd = Get-NetFirewallRule -DisplayName $ruleNameEpmd -ErrorAction SilentlyContinue
        if (-not $existingEpmd) {
            New-NetFirewallRule -DisplayName $ruleNameEpmd `
                                -Direction Inbound `
                                -Program $epmdFile.FullName `
                                -Action Allow `
                                -Profile Any | Out-Null
            Write-Host "[+] Created firewall rule for: $($epmdFile.FullName)" -ForegroundColor Green
        } else {
            Write-Host "[OK] Firewall rule for epmd.exe already exists" -ForegroundColor Gray
        }
    }
}

Write-Host "`n[SUCCESS] Windows Defender Firewall is configured for Erlang node communication!" -ForegroundColor Green
