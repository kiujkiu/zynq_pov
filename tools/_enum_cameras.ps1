Get-PnpDevice -Class Camera -Status OK | Format-Table FriendlyName, Status -AutoSize
Write-Host "---class Image---"
Get-PnpDevice -Class Image -Status OK | Format-Table FriendlyName, Status -AutoSize
