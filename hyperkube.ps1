$version = 'v1.0.3'
$workdir = "$HOME\hyperkube"
# $guestuser = $env:USERNAME.ToLower()
$guestuser = 'administrator'
$sshpath = "$HOME\.ssh\id_rsa.pub"
if (!(Test-Path $sshpath)) {
  Write-Host "`n please configure `$sshpath or place a pubkey at $sshpath `n"
  exit
}
$sshpub = $(Get-Content $sshpath -raw).trim()

$config = $(Get-Content -path .\.distro -ea silentlycontinue | Out-String).trim()
if (!$config) {
  $config = 'focal'
}

switch ($config) {
  'bionic' {
    $distro = 'ubuntu'
    $generation = 2
    $imgvers = "18.04"
    $imagebase = "https://cloud-images.ubuntu.com/releases/server/$imgvers/release"
    $sha256file = 'SHA256SUMS'
    $image = "ubuntu-$imgvers-server-cloudimg-amd64.img"
    $archive = ""
  }
  'focal' {
    $distro = 'ubuntu'
    $generation = 2
    $imgvers = "20.04"
    $imagebase = "https://cloud-images.ubuntu.com/releases/server/$imgvers/release"
    $sha256file = 'SHA256SUMS'
    $image = "ubuntu-$imgvers-server-cloudimg-amd64.img"
    $archive = ""
  }
}

$nettype = 'private' # private/public
$zwitch = 'K8s' # private or public switch name
$natnet = 'KubeNatNet' # private net nat net name (privnet only)
$adapter = 'Ethernet' # public net adapter name (pubnet only)

$cpu = 2
$ram = '4GB'
$hdd = '20GB'

$cidr = switch ($nettype) {
  'private' { '10.10.0' }
  'public' { $null }
}

$macs = @(
  '0225EA2C9AE7', # master
  '02A254C4612F', # node1
  '02FBB5136210', # node2
  '02FE66735ED6', # node3
  '021349558DC7', # node4
  '0288F589DCC3', # node5
  '02EF3D3E1283', # node6
  '0225849ADCBB', # node7
  '02E0B0026505', # node8
  '02069FBFC2B0', # node9
  '02F7E0C904D0' # node10
)

# https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64/repodata/filelists.xml
# https://packages.cloud.google.com/apt/dists/kubernetes-xenial/main/binary-amd64/Packages
# ctrl+f "kubeadm"
$kubeversion = '1.27.1-00'

$kubepackages = @"
  - docker-ce
  - docker-ce-cli
  - [ kubelet, $kubeversion ]
  - [ kubeadm, $kubeversion ]
  - [ kubectl, $kubeversion ]
"@

# downloads
$dockercli  = 'https://github.com/StefanScherer/docker-cli-builder/releases/download/20.10.9/docker.exe'
$kubectlcli = 'https://dl.k8s.io/release/v1.22.0/bin/windows/amd64/kubectl.exe'
$qemuimgcli = 'https://cloudbase.it/downloads/qemu-img-win-x64-2_3_0.zip'

$cni = 'flannel'

switch ($cni) {
  'flannel' {
    $cniyaml = 'https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml'
    $cninet = '10.244.0.0/16'
  }
  'weave' {
    $cniyaml = 'https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d "\n")'
    $cninet = '10.32.0.0/12'
  }
  'calico' {
    $cniyaml = 'https://docs.projectcalico.org/v3.7/manifests/calico.yaml'
    $cninet = '192.168.0.0/16'
  }
}

$sshopts = @('-o LogLevel=ERROR', '-o StrictHostKeyChecking=no', '-o UserKnownHostsFile=/dev/null')



# ----------------------------------------------------------------------

$imageurl = "$imagebase/$image$archive"
$srcimg   = "$workdir\$image"
$vhdxtmpl = "$workdir\$($image -replace '^(.+)\.[^.]+$', '$1').vhdx"

$toolsdir = "$workdir\tools"
$toolsbin = "$toolsdir\bin"


# switch to the script directory
Set-Location $PSScriptRoot | Out-Null

# stop on any error
$ErrorActionPreference = "Stop"
$PSDefaultParameterValues['*:ErrorAction'] = 'Stop'

$etchosts = "$env:windir\System32\drivers\etc\hosts"

# note: network configs version 1 an 2 didn't work
function Get-Metadata($vmname, $cblock, $ip) {
  if (!$cblock) {
    return @"
instance-id: id-$($vmname)
local-hostname: $($vmname)
"@
  }
  else {
    return @"
instance-id: id-$vmname
network-interfaces: |
  auto eth0
  iface eth0 inet static
  address $($cblock).$($ip)
  network $($cblock).0
  netmask 255.255.255.0
  broadcast $($cblock).255
  gateway $($cblock).1
local-hostname: $vmname
"@
  }
}

function Get-UserdataShared($cblock) {
  return @"
#cloud-config

mounts:
  - [ swap ]

groups:
  - docker

users:
  - name: $guestuser
    groups: sudo, docker
    shell: /bin/bash
    ssh_authorized_keys:
      - $($sshpub)
    sudo: ALL=(ALL) NOPASSWD:ALL

write_files:
  # resolv.conf hard-set is a workaround for intial setup
  - path: /etc/resolv.conf
    content: |
      nameserver 8.8.4.4
      nameserver 8.8.8.8
  - path: /etc/systemd/resolved.conf
    content: |
      [Resolve]
      DNS=8.8.4.4
      FallbackDNS=8.8.8.8
  - path: /root/append-etc-hosts
    content: |
      $(Set-HostsFile -cblock $cblock -prefix '      ')
  - path: /etc/modules-load.d/k8s.conf
    content: |
      br_netfilter
  - path: /etc/sysctl.d/k8s.conf
    content: |
      net.bridge.bridge-nf-call-ip6tables = 1
      net.bridge.bridge-nf-call-iptables = 1
      net.bridge.bridge-nf-call-arptables = 1
      net.ipv4.ip_forward = 1
  - path: /etc/docker/daemon.json
    content: |
      {
        "exec-opts": ["native.cgroupdriver=systemd"],
        "log-driver": "json-file",
        "log-opts": {
          "max-size": "100m"
        },
        "storage-driver": "overlay2",
        "storage-opts": [
          "overlay2.override_kernel_check=true"
        ]
      }
"@
}

function Get-UserdataUbuntu($cblock) {
return @"
$(Get-UserdataShared -cblock $cblock)
  - path: /etc/systemd/network/99-default.link
    content: |
      [Match]
      Path=/devices/virtual/net/*
      [Link]
      NamePolicy=kernel database onboard slot path
      MACAddressPolicy=none
      # https://github.com/clearlinux/distribution/issues/39
  - path: /etc/chrony/chrony.conf
    content: |
      refclock PHC /dev/ptp0 trust poll 2
      makestep 1 -1
      maxdistance 16.0
      #pool pool.ntp.org iburst
      driftfile /var/lib/chrony/chrony.drift
      logdir /var/log/chrony

apt:
  conf: |
      Acquire::Retries "180";
      DPkg::Lock::Timeout "180";
      APT {
          Get {
              Assume-Yes 'true';
              Fix-Broken 'true';
          }
      }
  sources:
    kubernetes:
      keyserver: "hkps://keyserver.ubuntu.com"
      keyid: A362B822F6DEDC652817EA46B53DC80D13EDEF05
      source: "deb [signed-by=/etc/apt/trusted.gpg.d/kubernetes.gpg] https://apt.kubernetes.io/ kubernetes-xenial main"
    docker.list:
      keyserver: "hkps://keyserver.ubuntu.com"
      keyid: 9DC858229FC7DD38854AE2D88D81803C0EBFCD88
      source: 'deb [arch=amd64 signed-by=/etc/apt/trusted.gpg.d/docker.gpg] https://download.docker.com/linux/ubuntu $config stable'

package_update: true

package_upgrade: true

packages:
  - linux-tools-virtual
  - linux-cloud-tools-virtual
  - nfs-common
  - chrony
  - apt-transport-https
  - ca-certificates
  - curl
  - gnupg
$kubepackages

power_state:
    delay: now
    mode: reboot
    timeout: 1
    message: Rebooting machine
    condition: true

# Capture all subprocess output into a logfile
# Useful for troubleshooting cloud-init issues
output: {all: '| tee -a /var/log/cloud-init-output.log'}

runcmd:
  - [ touch, "/home/$guestuser/.init-started" ]
  - echo "sudo tail -f /var/log/syslog" > /home/$guestuser/log
  - systemctl mask --now systemd-timesyncd
  - cat /root/append-etc-hosts >> /etc/hosts
  - systemctl stop kubelet
  - apt-mark hold kubelet kubeadm kubectl
  - chmod o+r /lib/systemd/system/kubelet.service
  - chmod o+r /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
  - systemctl enable --now chrony
  - mkdir -p /usr/libexec/hypervkvpd
  - ln -s /usr/sbin/hv_get_dns_info /usr/sbin/hv_get_dhcp_info /usr/libexec/hypervkvpd
  - sudo rm -f /etc/containerd/config.toml
  - sudo systemctl restart containerd
  - touch /home/$guestuser/.init-completed
#  - [docker, pull, hello-world]
#  - [docker, run, hello-world]
#  - [docker, images, hello-world]
"@
}

function New-PublicNet($zwitch, $adapter) {
  New-VMSwitch -name $zwitch -allowmanagementos $true -netadaptername $adapter | Format-List
}

function New-PrivateNet($natnet, $zwitch, $cblock) {
  New-VMSwitch -name $zwitch -switchtype internal | Format-List
  New-NetIPAddress -ipaddress "$($cblock).1" -prefixlength 24 -interfacealias "vEthernet ($zwitch)" | Format-List
  New-NetNat -name $natnet -internalipinterfaceaddressprefix "$($cblock).0/24" | Format-List
}

function Write-YamlContents($path, $cblock) {
  Set-Content $path ([byte[]][char[]] `
      "$(&"get-userdata$distro" -cblock $cblock)`n") -AsByteStream
}

function Write-ISOContents($vmname, $cblock, $ip) {
  mkdir $workdir\$vmname\cidata -ea 0 | Out-Null
  Set-Content $workdir\$vmname\cidata\meta-data ([byte[]][char[]] `
      "$(Get-Metadata -vmname $vmname -cblock $cblock -ip $ip)") -AsByteStream
  Write-YamlContents -path $workdir\$vmname\cidata\user-data -cblock $cblock
}

function New-ISO($vmname) {
  $fsi = new-object -ComObject IMAPI2FS.MsftFileSystemImage
  $fsi.FileSystemsToCreate = 3
  $fsi.VolumeName = 'cidata'
  $vmdir = (resolve-path -path "$workdir\$vmname").path
  $path = "$vmdir\cidata"
  $fsi.Root.AddTreeWithNamedStreams($path, $false)
  $isopath = "$vmdir\$vmname.iso"
  $res = $fsi.CreateResultImage()
#  $cp = New-Object CodeDom.Compiler.CompilerParameters
#  $cp.CompilerOptions = "/unsafe"
  if (!('ISOFile' -as [type])) {
    Add-Type -CompilerOptions "/unsafe" -TypeDefinition @"
      public class ISOFile {
        public unsafe static void Create(string iso, object stream, int blkSz, int blkCnt) {
          int bytes = 0; byte[] buf = new byte[blkSz];
          var ptr = (System.IntPtr)(&bytes); var o = System.IO.File.OpenWrite(iso);
          var i = stream as System.Runtime.InteropServices.ComTypes.IStream;
          if (o != null) { while (blkCnt-- > 0) { i.Read(buf, blkSz, ptr); o.Write(buf, 0, bytes); }
            o.Flush(); o.Close(); }}}
"@ 
  }
  [ISOFile]::Create($isopath, $res.ImageStream, $res.BlockSize, $res.TotalBlocks)
}

function New-Machine($zwitch, $vmname, $cpu, $ram, $hdd, $vhdxtmpl, $cblock, $ip, $mac) {
  $vmdir = "$workdir\$vmname"
  $vhdx = "$workdir\$vmname\$vmname.vhdx"

  if (!(Test-Path $vmdir)) {
    New-Item -itemtype directory -force -path $vmdir | Out-Null
  }
  if (!(Test-Path $vhdx)) {
    Copy-Item -path $vhdxtmpl -destination $vhdx -force
    Resize-VHD -path $vhdx -sizebytes $hdd
  }
#  if (!(Test-Path $workdir\isos)) {
#    New-Item -itemtype directory -force -path $vmdir # | Out-Null
#  }
#  if (!(Test-Path $workdir\isos\$vmname.iso)) {
#    Write-ISOContents -vmname $vmname -cblock $cblock -ip $ip
#    Copy-Item "$workdir\$vmname.iso" -Destination "$workdir\$vmname"
#  }

  # Create the VM
  New-VM -name $vmname -memorystartupbytes $ram -generation $generation `
    -switchname $zwitch -vhdpath $vhdx -path $workdir

  if ($generation -eq 2) {
    Set-VMFirmware -vmname $vmname -enablesecureboot off
  }

  Set-VMProcessor -vmname $vmname -count $cpu

  if (!$mac) { $mac = New-MacAddress }
  Get-VMNetworkAdapter -vmname $vmname | Set-VMNetworkAdapter -staticmacaddress $mac

  Set-VMComPort -vmname $vmname -number 2 -path \\.\pipe\$vmname
  Add-VMDvdDrive -vmname $vmname -path $workdir\$vmname\$vmname.iso

  Start-VM -name $vmname
}

# Write ISO file to local machine
function Write-ISO($zwitch, $vmname, $cpu, $ram, $hdd, $vhdxtmpl, $cblock, $ip, $mac) {
  $vmdir = "$workdir\$vmname"
  $vhdx = "$workdir\$vmname\$vmname.vhdx"
  New-Item -itemtype directory -force -path $vmdir | Out-Null
  if (!(Test-Path $vhdx)) {
    Copy-Item -path $vhdxtmpl -destination $vhdx -force
    Resize-VHD -path $vhdx -sizebytes $hdd

    Write-ISOContents -vmname $vmname -cblock $cblock -ip $ip
    New-ISO -vmname $vmname
  }
}

function Remove-Machine($name) {
  Stop-VM $name -turnoff -confirm:$false -ea inquire # silentlycontinue
  Remove-VM $name -force -ea inquire # silentlycontinue
  Remove-Item -recurse -force $workdir\$name
}

function Remove-PublicNet($zwitch) {
  Remove-VMswitch -name $zwitch -force -confirm:$false
}

function Remove-PrivateNet($zwitch, $natnet) {
  Remove-VMswitch -name $zwitch -force -confirm:$false
  Remove-NetNat -name $natnet -confirm:$false
}

function New-MacAddress() {
  return "02$((1..5 | ForEach-Object { '{0:X2}' -f (get-random -max 256) }) -join '')"
}

function basename($path) {
  return $path.substring(0, $path.lastindexof('.'))
}

function New-VHDXTmpl($imageurl, $srcimg, $vhdxtmpl) {
  if (!(Test-Path $workdir)) {
    mkdir $workdir | Out-Null
  }
  if (!(Test-Path $srcimg$archive)) {
    Get-File -url $imageurl -saveto $srcimg$archive
  }

  Get-Item -path $srcimg$archive | ForEach-Object { Write-Host 'srcimg:', $_.name, ([math]::round($_.length / 1MB, 2)), 'MB' }

  if ($sha256file) {
    $hash = shasum256 -shaurl "$imagebase/$sha256file" -diskitem $srcimg$archive -item $image$archive
    Write-Output "checksum: $hash"
  }
  else {
    Write-Output "no sha256file specified, skipping integrity ckeck"
  }

  if (($archive -eq '.tar.gz') -and (!(Test-Path $srcimg))) {
    tar xzf $srcimg$archive -C $workdir
  }
  elseif (($archive -eq '.xz') -and (!(Test-Path $srcimg))) {
    7z e $srcimg$archive "-o$workdir"
  }
  elseif (($archive -eq '.bz2') -and (!(Test-Path $srcimg))) {
    7z e $srcimg$archive "-o$workdir"
  }

  if (!(Test-Path $vhdxtmpl)) {
    Write-Output "vhdxtmpl: $vhdxtmpl"
    qemu-img.exe convert $srcimg -O vhdx -o subformat=dynamic $vhdxtmpl
  }

  Write-Output ''
  Get-Item -path $vhdxtmpl | ForEach-Object { Write-Host 'vhxdtmpl:', $_.name, ([math]::round($_.length / 1MB, 2)), 'MB' }
  return
}

function Get-File($url, $saveto) {
  Write-Output "downloading $url to $saveto"
  $progresspreference = 'silentlycontinue'
  Invoke-Webrequest $url -usebasicparsing -outfile $saveto # too slow w/ indicator
  $progresspreference = 'continue'
}

function Set-HostsFile($cblock, $prefix) {
  $ret = switch ($nettype) {
    'private' {
      @"
#
$prefix#
$prefix$($cblock).10 master
$prefix$($cblock).11 node1
$prefix$($cblock).12 node2
$prefix$($cblock).13 node3
$prefix$($cblock).14 node4
$prefix$($cblock).15 node5
$prefix$($cblock).16 node6
$prefix$($cblock).17 node7
$prefix$($cblock).18 node8
$prefix$($cblock).19 node9
$prefix#
$prefix#
"@
    }
    'public' {
      ''
    }
  }
  return $ret
}

function Update-HostsFile($cblock) {
  Set-HostsFile -cblock $cblock -prefix '' | Out-File -encoding utf8 -append $etchosts
  Get-Content $etchosts
}


####### this isn't used ###########
##                               ##
###################################
function New-Nodes($num, $cblock) {
  1..$num | ForEach-Object {
    Write-Output creating node $_
    New-Machine -zwitch $zwitch -vmname "node$_" -cpus 4 -mem 4GB -hdd 40GB `
      -vhdxtmpl $vhdxtmpl -cblock $cblock -ip $(10 + $_)
  }
}

function Remove-Nodes($num) {
  1..$num | ForEach-Object {
    Write-Output deleting node $_
    Remove-Machine -name "node$_"
  }
}

function Get-K8sVM() {
  return get-vm | Where-Object { ($_.name -match 'master|node.*') }
}

function get-our-running-vms() {
  return get-vm | Where-Object { ($_.state -eq 'running') -and ($_.name -match 'master|node.*') }
}

function shasum256($shaurl, $diskitem, $item) {
  $pat = "^(\S+)\s+\*?$([regex]::escape($item))$"

  $hash = Get-Filehash -algo sha256 -path $diskitem | ForEach-Object { $_.hash }

  $webhash = ( Invoke-Webrequest $shaurl -usebasicparsing ).tostring().split("`n") | `
    Select-String $pat | ForEach-Object { $_.matches.groups[1].value }

  if (!($hash -ieq $webhash)) {
    throw @"
    SHA256 MISMATCH:
       shaurl: $shaurl
         item: $item
     diskitem: $diskitem
     diskhash: $hash
      webhash: $webhash
"@
  }
  return $hash
}

function Get-Ctrlc() {
  if ([console]::KeyAvailable) {
    $key = [system.console]::readkey($true)
    if (($key.modifiers -band [consolemodifiers]"control") -and ($key.key -eq "C")) {
      return $true
    }
  }
  return $false;
}

function Wait-NodeInit($opts, $name) {
#  ssh $opts $guestuser@master 'sudo reboot 2> /dev/null'
  while ( ! $(ssh $opts $guestuser@master 'ls ~/.init-completed 2> /dev/null') ) {
    ### should be able to use /var/lib/cloud/instance/boot-finished instead?
    Write-Output "waiting for $name to init..."
    Start-Sleep -seconds 5
    if ( Get-Ctrlc ) { exit 1 }
  }
}

function Convert-UNCPath($path) {
  $item = Get-Item $path
  return $path.replace($item.root, '/').replace('\', '/')
}

function Convert-UNCPath2($path) {
  return ($path -replace '^[^:]*:?(.+)$', "`$1").replace('\', '/')
}

function Read-cpu($name) {
#  $conf = "config\$vmname.conf"
#  if (!(Test-Path $conf)) {
#    Write-Host "Config missing.  Create $conf and try again"
#    return $False
#  }  
	Get-ChildItem -Path .\ -Filter *.conf -Recurse -File| Sort-Object Length -Descending | ForEach-Object {
	 	       $vmname=$_.BaseName
		       $vmname = Get-Content $_.FullName | Out-String | ConvertFrom-StringData
#		       $_.BaseName
#		       $vmname.cpu
#		       $vmname.ram
#		       $vmname.hdd
		       }
	return ($name.cpu)
}

function Read-ram($name) {
	Get-ChildItem -Path .\ -Filter *.conf -Recurse -File| Sort-Object Length -Descending | ForEach-Object {
	 	       $vmname=$_.BaseName
		       $vmname = Get-Content $_.FullName | Out-String | ConvertFrom-StringData
		       }
	return ($name.ram)
}

function Read-hdd($name) {
	Get-ChildItem -Path .\ -Filter *.conf -Recurse -File| Sort-Object Length -Descending | ForEach-Object {
	 	       $vmname=$_.BaseName
		       $vmname = Get-Content $_.FullName | Out-String | ConvertFrom-StringData
		       }
	return ($name.hdd)
}

function Show-Aliases($pwsalias, $bashalias) {
  Write-Output ""
  Write-Output "powershell alias:"
  Write-Output "  write-output '$pwsalias' | Out-File -encoding utf8 -append `$profile"
  Write-Output ""
  Write-Output "bash alias:"
  Write-Output "  write-output `"``n$($bashalias.replace('\', '\\'))``n`" | Out-File -encoding utf8 -append -nonewline ~\.profile"
  Write-Output ""
  Write-Output "  -> restart your shell after applying the above"
}

function Save-KubeConf() {
  New-Item -itemtype directory -force -path $HOME\.kube | Out-Null
  scp $sshopts $guestuser@master:.kube/config $HOME\.kube\config

  $cachedir = "$HOME\.kube\cache\discovery\$cidr.10_6443"
  if (Test-Path $cachedir) {
    Write-Output ""
    Write-Output "deleting previous $cachedir"
    Write-Output ""
    Remove-Item $cachedir -recurse
  }

  Write-Output "executing: kubectl get pods --all-namespaces`n"
  kubectl get pods --all-namespaces
  Write-Output ""
  Write-Output "executing: kubectl get nodes`n"
  kubectl get nodes
}


Write-Output ''

if ($args.count -eq 0) {
  $args = @( 'help' )
}

switch -regex ($args) {
  ^help$ {
    Write-Output @"
  Practice real Kubernetes configurations on a local multi-node cluster.
  Inspect and optionally customize this script before use.

  Usage: .\hyperkube.ps1 command+

  Commands:

     (pre-requisites are marked with ->)

       Install-Tools - Install packages kubectl, docker, qemu-img
         Show-Config - Show script config vars
      Deploy-Network - Install private or public host network
    Deploy-HostsFile - Append private network node names to etc/hosts
           Get-Image - Download the VM image
       Deploy-Master - Create and launch master node
        Deploy-NodeN - Create and launch worker node (node1, node2, ...)
      Save-ISOMaster - Save master node iso
       Save-ISONodeN - Save worker node iso (node1, node2, ...)
            Get-Info - Display info about nodes
  Initialize-Kubeadm - Initialize kubeadm
   Start-KubeadmJoin - Run Kubeadm join command
     Save-KubeConfig - Save Kube config to host
          Save-K8sVM - Snapshot the VMs
       Restore-K8sVM - Restore VMs from latest snapshots
         Start-K8sVM - Start the VMs
       Restart-K8sVM - Soft-reboot the VMs
         Reset-K8sVM - Hard-reboot the VMs
      Shutdown-K8sVM - Soft-shutdown the VMs
          Stop-K8sVM - Hard-Stop the VMs
        Remove-K8sVM - Stop VMs and delete the VM files
      Remove-Network - Delete the network
"@
  }
  ^Install-Tools$ {
#      Remove-Item $toolsdir -Force -Recurse
    if (!(Test-Path $toolsdir)) {
      New-Item -Path $workdir -Name "tools" -ItemType "directory"
    }
    if (!(Test-Path $toolsbin)) {
      New-Item -Path $workdir\tools -Name "bin" -ItemType "directory"      
    }

    # Install qemu-img
    Invoke-WebRequest -Uri "$qemuimgcli" -OutFile "$toolsdir\qemu-img.zip"
    Expand-Archive -LiteralPath "$workdir\qemu-img.zip" -DestinationPath "$toolsbin"
    Remove-Item "$toolsdir\qemu-img.zip"

    # Install kubectl
    Invoke-WebRequest -Uri "$kubectlcli" -OutFile "$toolsbin\kubectl.exe"

    # Install docker cli
    Invoke-WebRequest -Uri "$dockercli" -OutFile "$toolsbin\docker.exe"

    # Add to PATH    
    $oldPath = (Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH).Path
    $newPath = "$oldPath;$toolsbin"    
    Set-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH -Value $newPath
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
  }
  ^Show-Config$ {
    Write-Output "   version: $version"
    Write-Output "    config: $config"
    Write-Output "    distro: $distro"
    Write-Output "   workdir: $workdir"
    Write-Output " guestuser: $guestuser"
    Write-Output "   sshpath: $sshpath"
    Write-Output "   sshopts: $sshopts"
    Write-Output "  imageurl: $imageurl"
    Write-Output "  vhdxtmpl: $vhdxtmpl"
    Write-Output "      cidr: $cidr.0/24"
    Write-Output "    switch: $zwitch"
    Write-Output "   nettype: $nettype"
    switch ($nettype) {
      'private' { Write-Output "    natnet: $natnet" }
      'public' { Write-Output "   adapter: $adapter" }
    }
    Write-Output "      cpus: $cpu"
    Write-Output "       ram: $ram"
    Write-Output "       hdd: $hdd"
    Write-Output "       cni: $cni"
    Write-Output "    cninet: $cninet"
    Write-Output "   cniyaml: $cniyaml"
    Write-Output " dockercli: $dockercli"
  }
  ^Deploy-Network$ {
    switch ($nettype) {
      'private' { New-PrivateNet -natnet $natnet -zwitch $zwitch -cblock $cidr }
      'public' { New-PublicNet -zwitch $zwitch -adapter $adapter }
    }
  }
  ^Deploy-HostsFile$ {
    switch ($nettype) {
      'private' { Update-HostsFile -cblock $cidr }
      'public' { Write-Output "not supported for public net - use dhcp" }
    }
  }
  ^Show-Macs$ {
    $cnt = 10
    0..$cnt | ForEach-Object {
      $comment = switch ($_) { 0 { 'master' } default { "node$_" } }
      $comma = if ($_ -eq $cnt) { '' } else { ',' }
      Write-Output "  '$(New-MacAddress)'$comma # $comment"
    }
  }
  ^Get-Image$ {
    New-VHDXTmpl -imageurl $imageurl -srcimg $srcimg -vhdxtmpl $vhdxtmpl
  }
  ^Deploy-Master$ {
    $name = "master"
    $cpu=$(Read-cpu -name $name)
    $ram=$(Read-ram -name $name)
    $hdd=$(Read-hdd -name $name)
    New-Machine -zwitch $zwitch -vmname 'master' -cpus $cpu `
      -mem $(Invoke-Expression $ram) -hdd $(Invoke-Expression $hdd) `
      -vhdxtmpl $vhdxtmpl -cblock $cidr -ip '10' -mac $macs[0]
  }
  '(^Deploy-Node(?<number>\d+)$)' {
    $num = [int]$matches.number
    $name = "node$($num)"
    $cpu=$(Read-cpu -name $name)
    $ram=$(Read-ram -name $name)
    $hdd=$(Read-hdd -name $name)
    New-Machine -zwitch $zwitch -vmname $name -cpus $cpu `
      -mem $(Invoke-Expression $ram) -hdd $(Invoke-Expression $hdd) `
      -vhdxtmpl $vhdxtmpl -cblock $cidr -ip "$($num + 10)" -mac $macs[$num]
  }
  ^Save-ISOMaster$ {
    $name = "master"
    $cpu=$(Read-cpu -name $name)
    $ram=$(Read-ram -name $name)
    $hdd=$(Read-hdd -name $name)
    Write-ISO -zwitch $zwitch -vmname 'master' -cpus $cpu `
      -mem $(Invoke-Expression $ram) -hdd $(Invoke-Expression $hdd) `
      -vhdxtmpl $vhdxtmpl -cblock $cidr -ip '10' -mac $macs[0]
  }
  '(^Save-ISONode(?<number>\d+)$)' {
    $num = [int]$matches.number
    $name = "node$($num)"
    $cpu=$(Read-cpu -name $name)
    $ram=$(Read-ram -name $name)
    $hdd=$(Read-hdd -name $name)
    Write-ISO -zwitch $zwitch -vmname $name -cpus $cpu `
      -mem $(Invoke-Expression $ram) -hdd $(Invoke-Expression $hdd) `
      -vhdxtmpl $vhdxtmpl -cblock $cidr -ip "$($num + 10)" -mac $macs[$num]
  }
  ^Get-Info$ {
    Get-K8sVM
  }
  ^Initialize-Kubeadm$ { 
    # wait for each node to initialize before continuing
    Get-K8sVM | ForEach-Object { Wait-NodeInit -opts $sshopts -name $_.name }

    Write-Output "`ninitializing master"
    
    $init = "sudo kubeadm init --pod-network-cidr=$cninet && \
      mkdir -p `$HOME/.kube && \
      sudo cp /etc/kubernetes/admin.conf `$HOME/.kube/config && \
      sudo chown `$(id -u):`$(id -g) `$HOME/.kube/config && \
      kubectl apply -f `$(eval echo $cniyaml)"

    Write-Output "executing on master: $init"

    ssh $sshopts $guestuser@master $init
    if (!$?) {
      Write-Output "master init has failed, aborting"
      exit 1
    }
  }
  ^Start-KubeadmJoin$ {
    if ((Get-K8sVM | Where-Object { $_.name -match "node.+" }).count -eq 0) {
      Write-Output ""
      Write-Output "no worker nodes, removing NoSchedule taint from master..."
      ssh $sshopts $guestuser@master 'kubectl taint nodes master node-role.kubernetes.io/master:NoSchedule-'
      Write-Output ""
    }
    else {
      $joincmd = $(ssh $sshopts $guestuser@master 'sudo kubeadm token create --print-join-command')
      Get-K8sVM | Where-Object { $_.name -match "node.+" } |
      ForEach-Object {
        $node = $_.name
        Write-Output "`nexecuting on $node`: $joincmd"
        ssh $sshopts $guestuser@$node sudo $joincmd
        if (!$?) {
          Write-Output "$node init has failed, aborting"
          exit 1
        }
      }
    }
  }
  ^Save-KubeConfig$ {
    Save-KubeConf
  }
  ^Restart-K8sVM$ {
    Get-K8sVM | ForEach-Object {
      $node = $_.name
      Write-Output "`nrebooting $node"
      ssh $sshopts $guestuser@$node 'sudo reboot 2> /dev/null'
      }
  }
  ^Shutdown-K8sVM$ {
    Get-K8sVM | ForEach-Object { $node = $_.name; $(ssh $sshopts $guestuser@$node 'sudo shutdown -h now') }
  }
  ^Save-K8sVM$ {
    Get-K8sVM | Checkpoint-VM
  }
  ^Restore-K8sVM$ {
    Get-K8sVM | Foreach-Object { $_ | Get-VMSnapshot | Sort-Object creationtime | `
        Select-Object -last 1 | Restore-VMSnapshot -confirm:$false }
  }
  ^Reset-K8sVM$ {
    Get-K8sVM | Restart-VM -Confirm:$False
  }
  ^Stop-K8sVM$ {
    Get-K8sVM | Stop-VM -Confirm:$False
  }
  ^Start-K8sVM$ {
    Get-K8sVM | Start-VM
  }
  ^Remove-K8sVM$ {
    Get-K8sVM | ForEach-Object { Remove-Machine -name $_.name }
  }
  ^Remove-Network$ {
    switch ($nettype) {
      'private' { Remove-PrivateNet -zwitch $zwitch -natnet $natnet }
      'public' { Remove-PublicNet -zwitch $zwitch }
    }
  }
  ^Get-Time$ {
    Write-Output "local: $(Get-date)"
    Get-K8sVM | ForEach-Object {
      $node = $_.name
      Write-Output ---------------------$node
      # ssh $sshopts $guestuser@$node "date ; if which chronyc > /dev/null; then sudo chronyc makestep ; date; fi"
      ssh $sshopts $guestuser@$node "date"
    }
  }
  ^Start-Track$ {
    Get-K8sVM | ForEach-Object {
      $node = $_.name
      Write-Output ---------------------$node
      ssh $sshopts $guestuser@$node "date ; sudo chronyc tracking"
    }
  }
  ^Show-DockerConfig$ {
    Write-Output ""
    Write-Output "powershell:"
    Write-Output "  write-output '`$env:DOCKER_HOST = `"ssh://$guestuser@master`"' | Out-File -encoding utf8 -append `$profile"
    Write-Output ""
    Write-Output "bash:"
    Write-Output "  write-output `"``nexport DOCKER_HOST='ssh://$guestuser@master'``n`" | Out-File -encoding utf8 -append -nonewline ~\.profile"
    Write-Output ""
    Write-Output ""
    Write-Output "(restart your shell after applying the above)"
  }
  default {
    Write-Output 'invalid command; try: .\hyperkube.ps1 help'
  }
}

Write-Output ''
