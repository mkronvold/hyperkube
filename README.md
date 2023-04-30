# hyperv-k8s
PowerShell script to deploy Kubernetes cluster on Microsoft Hyper-V Server

# Quick Guide

✅Hyper-V server:
- Generate SSH Public key: ssh-keygen

✅Windows client:
- Run PowerShell as Admin and cd to $Home\hyperkube
- Go to Window Admin Center  download public ssh key and save to `$Home\.ssh`
- Download and setup Qemu-Img portable
- curl https://cloudbase.it/downloads/qemu-img-win-x64-2_3_0.zip -o qemu-img.zip
- 7z x .\qemu-img.zip
- set-executionpolicy remotesigned
- del .\hyperv-k8s.ps1
- curl https://raw.githubusercontent.com/mkronvold/hyperv-k8s/main/hyperv-k8s.ps1 -o hyperv-k8s.ps1
- .\hyperv-k8s.ps1 Get-Image
- .\hyperv-k8s.ps1 Save-ISOMaster
- .\hyperv-k8s.ps1 Save-ISONode1

✅Windows hyper-v server (can be same machine):
- Upload created isos (on Windows client) to `C:\Users\${username}\hyperkube`
- Run PowerShell as Administrator
- cd $Home\hyperkube
- curl https://raw.githubusercontent.com/mkronvold/hyperv-k8s/main/hyperv-k8s.ps1 -o hyperv-k8s.ps1
- .\hyperv-k8s.ps1 Install-Tools
- .\hyperv-k8s.ps1 Deploy-HostsFile
- .\hyperv-k8s.ps1 Deploy-Network
- .\hyperv-k8s.ps1 Get-Image
- .\hyperv-k8s.ps1 Deploy-Master
- .\hyperv-k8s.ps1 Deploy-Node1
- .\hyperv-k8s.ps1 Initialize-Kubeadm
- .\hyperv-k8s.ps1 Start-KubeadmJoin
- .\hyperv-k8s.ps1 Save-KubeConfig

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


