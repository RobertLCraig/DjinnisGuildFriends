param(
    [string]$AddonName = "DjinnisGuildFriends",
    [string]$Source = (Split-Path -Parent $MyInvocation.MyCommand.Definition),
    [string]$Destination = "C:/Games/World of Warcraft/_retail_/Interface/AddOns",
    [switch]$DryRun
)

$DestPath = Join-Path $Destination $AddonName

# Exclusions
$Excludes = @(
    "DjinnisGuildFriendsDB.lua"
    ".git"
    ".gitignore"
    ".claude"
    "CLAUDE.md"
    "Docs"
    "README.md"
    "deploy.sh"
)

function Write-Info($msg) {
    Write-Host $msg -ForegroundColor Cyan
}

function Write-Success($msg) {
    Write-Host $msg -ForegroundColor Green
}

function Write-Warn($msg) {
    Write-Host $msg -ForegroundColor Yellow
}

Write-Info "=== Deploying $AddonName ==="
Write-Info "Source:      $Source"
Write-Info "Destination: $DestPath"
if ($DryRun) { Write-Warn "Dry Run: No files will be copied or deleted" }

# Ensure destination exists
if (-not (Test-Path $DestPath)) {
    if ($DryRun) {
        Write-Warn "[DryRun] Would create directory: $DestPath"
    } else {
        New-Item -ItemType Directory -Path $DestPath | Out-Null
    }
}

# Build robocopy args
$ExcludeFiles   = $Excludes | Where-Object { $_ -match '\.' }
$ExcludeFolders = $Excludes | Where-Object { $_ -notmatch '\.' }

$RoboArgs = @(
    "`"$Source`"", "`"$DestPath`"",
    "/MIR",
    "/NFL", "/NDL", "/NJH", "/NJS", "/NP"
)

foreach ($file in $ExcludeFiles)   { $RoboArgs += "/XF `"$file`"" }
foreach ($dir  in $ExcludeFolders) { $RoboArgs += "/XD `"$dir`"" }

if ($DryRun) {
    Write-Warn "[DryRun] Robocopy would run with arguments:"
    $RoboArgs | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
} else {
    robocopy @RoboArgs | Out-Null
}

Write-Success "Deploy complete!"