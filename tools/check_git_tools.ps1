# Check Git for Windows + TortoiseGit installation state
Write-Host "=== Git for Windows ===" -ForegroundColor Cyan
$gitCmd = Get-Command git -ErrorAction SilentlyContinue
if ($gitCmd) {
    Write-Host "Installed: $($gitCmd.Source)"
    git --version
} else {
    Write-Host "NOT installed"
}

Write-Host "`n=== TortoiseGit ===" -ForegroundColor Cyan
$tgit = @(
    'C:\Program Files\TortoiseGit',
    'C:\Program Files (x86)\TortoiseGit'
) | Where-Object { Test-Path $_ }
if ($tgit) {
    Write-Host "Installed at: $tgit"
} else {
    Write-Host "NOT installed"
}

Write-Host "`n=== winget availability ===" -ForegroundColor Cyan
$winget = Get-Command winget -ErrorAction SilentlyContinue
if ($winget) {
    Write-Host "winget available: $($winget.Source)"
} else {
    Write-Host "winget NOT available (need Windows 10 1809+ / App Installer)"
}
