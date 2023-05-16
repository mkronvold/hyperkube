# hyperkube
PowerShell script to deploy Kubernetes cluster on Microsoft Hyper-V Server

forked from https://github.com/nvtienanh/hyperv-k8s and customized for my own use on a stand alone windows 2022 server.

## Get git
```
winget install --id Git.Git -e --source winget
```

# Quick Guide

✅Hyper-V server:
- Generate SSH Public key
```
ssh-keygen
```

✅Windows client:
- Run PowerShell as Admin
- Go to Window Admin Center  download public ssh key and save to `$Home\.ssh`
- Download and setup Qemu-Img portable
```
cd to $Home\hyperkube
curl https://cloudbase.it/downloads/qemu-img-win-x64-2_3_0.zip -o qemu-img.zip
7z x .\qemu-img.zip
set-executionpolicy remotesigned
del .\hyperkube.ps1
curl https://raw.githubusercontent.com/mkronvold/hyperkube/main/hyperkube.ps1 -o hyperkube.ps1
.\hyperkube.ps1 Get-Image
.\hyperkube.ps1 Save-ISOMaster
.\hyperkube.ps1 Save-ISONode1
```

✅Windows hyper-v server (can be same machine):
- Upload created isos (on Windows client) to `C:\Users\${username}\hyperkube`
- Run PowerShell as Administrator
```
cd $Home\hyperkube
curl https://raw.githubusercontent.com/mkronvold/hyperkube/main/hyperkube.ps1 -o hyperkube.ps1
.\hyperkube.ps1 Install-Tools
.\hyperkube.ps1 Deploy-HostsFile
.\hyperkube.ps1 Deploy-Network
.\hyperkube.ps1 Get-Image
.\hyperkube.ps1 Deploy-Master
.\hyperkube.ps1 Deploy-Node1
.\hyperkube.ps1 Initialize-Kubeadm
.\hyperkube.ps1 Start-KubeadmJoin
.\hyperkube.ps1 Save-KubeConfig
```
# Commands

You have to Start Powershell as administartor and run command `set-executionpolicy remotesigned`. It make all scripts and configuration files downloaded from the Internet are signed by a trusted publisher.

- `Install-Tools`: Install packages kubectl, docker, qemu-img
- `Show-Config`: show script config vars
- `Deploy-Network`: install private or public host network
- `Deploy-HostsFile`: append private network node names to etc/hosts
- `Get-Image`: download the VM image
- `Deploy-Master`: create and launch master node
- `Deploy-NodeN`: create and launch worker node (node1, node2, ...)
- `Save-ISOMaster`: save master node
- `Save-ISONodeN`: save worker node (node1, node2, ...)
- `Get-Info`: display info about nodes
- `Initialize-Kubeadm`: Initialize kubeadm
- `Start-KubeadmJoin`: Run Kubeadm joind command
- `Save-KubeConfig`: Save Kube config to host
- `Restart-K8sVM`: Soft-reboot the nodes
- `Shutdown-K8sVM`: Soft-shutdown the nodes
- `Save-K8sVM`: Snapshot the VMs
- `Restore-K8sVM`: Restore VMs from latest snapshots
- `Stop-K8sVM`: Stop the VMs
- `Start-K8sVM`: Start the VMs
- `Remove-K8sVM`: Stop VMs and delete the VM files
- `Remove-Network`: Delete the network

# How to use it

- [Microsoft Hyper-V Server: Deploy a Kubernetes cluster](https://www.youtube.com/watch?v=MPjavnlRnQU)

# References
- https://github.com/youurayy/hyperctl

