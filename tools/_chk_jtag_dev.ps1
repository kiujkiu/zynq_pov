Get-PnpDevice | Where-Object {
    $_.InstanceId -like '*VID_0403*' -or
    $_.FriendlyName -like '*FT*' -or
    $_.FriendlyName -like '*JTAG*' -or
    $_.FriendlyName -like '*Digilent*' -or
    $_.FriendlyName -like '*USB Serial*'
} | Format-Table -AutoSize FriendlyName, Status, Class, InstanceId
