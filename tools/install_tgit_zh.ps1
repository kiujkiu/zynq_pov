$url = 'https://download.tortoisegit.org/tgit/2.18.0.0/TortoiseGit-LanguagePack-2.18.0.0-64bit-zh_CN.msi'
$out = 'D:\workspace\zynq_pov\TortoiseGit-zh_CN.msi'
Write-Host "Downloading TortoiseGit Chinese language pack..."
try {
    Invoke-WebRequest -Uri $url -OutFile $out -UseBasicParsing
    Write-Host "OK downloaded to $out"
    Get-Item $out | Select-Object Length, FullName
} catch {
    Write-Host "Download failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
Write-Host "`nInstalling (will trigger UAC)..."
Start-Process msiexec.exe -ArgumentList "/i `"$out`" /qb" -Verb RunAs -Wait
Write-Host "Install done. Right-click in Explorer → TortoiseGit → Settings → General → Language 设成 简体中文."
