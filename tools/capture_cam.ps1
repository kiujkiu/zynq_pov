# Use Windows.Media.Capture to grab a still from default webcam
Add-Type -AssemblyName System.Runtime.WindowsRuntime
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$out = "D:\workspace\zynq_pov\tools\cam_snap.jpg"

# Try via WIA (Windows Image Acquisition)
$deviceManager = New-Object -ComObject WIA.DeviceManager
$device = $null
foreach ($info in $deviceManager.DeviceInfos) {
    if ($info.Type -eq 2) {  # Webcam type
        $device = $info.Connect()
        Write-Host "Connected: $($info.Properties['Name'].Value)"
        break
    }
}
if ($device -eq $null) {
    Write-Host "No camera found via WIA"
    exit 1
}
$item = $device.ExecuteCommand("{AF933CAC-ACAD-11D2-A093-00C04F72DC3C}")  # Take picture
$image = $item.Transfer()
$image.SaveFile($out)
Write-Host "Saved to $out"
