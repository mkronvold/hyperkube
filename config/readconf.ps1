$Path = "master.conf"
$values = Get-Content $Path | Out-String | ConvertFrom-StringData
$values.cpu
$values.ram
$values.hdd
