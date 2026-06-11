Get-Item C:\Windows\System32\dmgr.dll, C:\Windows\System32\djtg.dll, C:\Windows\System32\dpcutil.dll | ForEach-Object {
    [PSCustomObject]@{
        Name = $_.Name
        Version = $_.VersionInfo.FileVersion
        Modified = $_.LastWriteTime
        Size = $_.Length
    }
} | Format-Table -AutoSize

Write-Host "`n=== djtgcfg (Digilent JTAG CLI) ==="
Get-Command djtgcfg -ErrorAction SilentlyContinue | Format-List Name, Source, Version
Get-ChildItem 'C:\Program Files\Digilent\Adept2 Runtime\','C:\Program Files (x86)\Digilent\Adept2 Runtime\','C:\Program Files (x86)\Digilent\Runtime\' -Recurse -Include djtgcfg.exe -ErrorAction SilentlyContinue | Format-List FullName
