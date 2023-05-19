function Read-cpu($name) {
#      if (!(Test-Path $conf)) {
#          Write-Host "Config missing.  Create $conf and try again"
#          return $False
#      }
	Get-ChildItem -Path .\$name.conf -Recurse -File| Sort-Object Length -Descending | ForEach-Object {
	    $vmname=$_.BaseName
	    $vmname = Get-Content $_.FullName | Out-String | ConvertFrom-StringData
	}
      return ($vmname.cpu)
}


function Read-ram($name) {
	Get-ChildItem -Path .\$name.conf -Recurse -File| Sort-Object Length -Descending | ForEach-Object {
	    $vmname=$_.BaseName
	    $vmname = Get-Content $_.FullName | Out-String | ConvertFrom-StringData
	}
return ($vmname.ram)
}


function Read-hdd($name) {
	Get-ChildItem -Path .\$name.conf -Recurse -File| Sort-Object Length -Descending | ForEach-Object {
	    $vmname=$_.BaseName
	    $vmname = Get-Content $_.FullName | Out-String | ConvertFrom-StringData
	}
return ($vmname.hdd)
}

read-ram -name master




