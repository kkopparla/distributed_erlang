<#
.SYNOPSIS
    Distributed Bitcoin Mining Runner (PowerShell)
.DESCRIPTION
    Runs the Erlang project in Server or Worker mode.
.EXAMPLE
    Server mode:
        .\project1.ps1 4
        .\project1.ps1 4 myprefix
    Worker mode:
        .\project1.ps1 192.168.0.152
#>

param(
    [Parameter(Position=0, Mandatory=$false)]
    [string]$Arg1,

    [Parameter(Position=1, Mandatory=$false)]
    [string]$Arg2
)

$Cookie = "bitcoin_secret"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $ScriptDir

# Check Erlang installation
if (-not (Get-Command erl -ErrorAction SilentlyContinue)) {
    Write-Error "Erlang 'erl' was not found in PATH. Please ensure Erlang/OTP is installed and added to PATH."
    exit 1
}

# Ensure ebin directory exists and compile sources
if (-not (Test-Path "ebin")) {
    New-Item -ItemType Directory -Force -Path "ebin" | Out-Null
}

$ErlFiles = Get-ChildItem -Path "src\*.erl"
$NeedsCompile = $false
foreach ($f in $ErlFiles) {
    $beamPath = Join-Path "ebin" ($f.BaseName + ".beam")
    if (-not (Test-Path $beamPath) -or ($f.LastWriteTime -gt (Get-Item $beamPath).LastWriteTime)) {
        $NeedsCompile = $true
        break
    }
}

if ($NeedsCompile) {
    Write-Host "[*] Compiling Erlang source files..." -ForegroundColor Cyan
    erlc -W -o ebin ($ErlFiles | ForEach-Object { $_.FullName })
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Compilation failed."
        exit $LASTEXITCODE
    }
}

if (-not $Arg1) {
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  Server mode: .\project1.ps1 <leading_zeros> [prefix]"
    Write-Host "               Example: .\project1.ps1 4"
    Write-Host "  Worker mode: .\project1.ps1 <server_ip>"
    Write-Host "               Example: .\project1.ps1 192.168.0.152"
    exit 0
}

# Function to auto-detect local IPv4 address
function Get-LocalIP {
    # Try active Wi-Fi adapter first
    $wifi = Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias 'Wi-Fi*' -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -notlike "169.254.*" -and $_.IPAddress -ne "127.0.0.1" } |
        Select-Object -First 1
    if ($wifi) { return $wifi.IPAddress }

    # Fallback to any active non-loopback, non-APIPA IPv4
    $anyIp = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object {
            $_.IPAddress -notlike "127.*" -and
            $_.IPAddress -notlike "169.254.*" -and
            $_.IPAddress -notlike "192.168.137.*"
        } | Select-Object -First 1
    if ($anyIp) { return $anyIp.IPAddress }

    return "127.0.0.1"
}

$LocalIP = Get-LocalIP

$isInteger = $Arg1 -match '^\d+$'

if ($isInteger) {
    # Server Mode
    $NodeName = "server@$LocalIP"
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host " Starting Server Node: $NodeName" -ForegroundColor Green
    Write-Host " Target: $Arg1 leading zeros" -ForegroundColor Green
    Write-Host " Listening on Wi-Fi IP: $LocalIP" -ForegroundColor Green
    Write-Host " Other machines can connect via: .\project1.ps1 $LocalIP" -ForegroundColor Yellow
    Write-Host "============================================================" -ForegroundColor Green

    $runArgs = @($Arg1)
    if ($Arg2) { $runArgs += $Arg2 }

    erl -pa ebin `
        -name $NodeName `
        -setcookie $Cookie `
        -noshell `
        -run project1 main @runArgs
} else {
    # Worker Mode
    $RandId = Get-Random -Minimum 1000 -Maximum 9999
    $NodeName = "worker_${RandId}@$LocalIP"
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " Starting Worker Node: $NodeName" -ForegroundColor Cyan
    Write-Host " Connecting to Server: $Arg1" -ForegroundColor Cyan
    Write-Host " Silent mode: All found coins are printed on Server." -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan

    erl -pa ebin `
        -name $NodeName `
        -setcookie $Cookie `
        -noshell `
        -run project1 main $Arg1
}
