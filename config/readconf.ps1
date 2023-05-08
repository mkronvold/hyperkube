Get-ChildItem -Path .\ -Filter *.conf -Recurse -File| Sort-Object Length -Descending | ForEach-Object {
    $vmname=$_.BaseName
    $vmname = Get-Content $_.FullName | Out-String | ConvertFrom-StringData
     $_.BaseName
     $vmname.cpu
     $vmname.ram
     $vmname.hdd
}



