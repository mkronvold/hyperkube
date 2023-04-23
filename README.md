# hyperv-k8s
PowerShell script to deploy Kubernetes cluster on Microsoft Hyper-V Server

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
- `Invoke-Shutdown`: Soft-shutdown the nodes
- `Save-K8sVM`: Snapshot the VMs
- `Restore-K8sVM`: Restore VMs from latest snapshots
- `Stop-K8sVM`: Stop the VMs
- `Start-K8sVM`: Start the VMs
- `Remove-K8sVM`: Stop VMs and delete the VM files
- `Remove-Network`: Delete the network

# How to use it

- [Microsoft Hyper-V Server: Deploy a Kubernetes cluster](https://www.youtube.com/watch?v=MPjavnlRnQU)

# Refereces
- https://github.com/youurayy/hyperctl

# From howto video
✅Hyper-V server:
- Generate SSH Public key: ssh-keygen
✅Windows client:
- Go to Window Admin Center  download public ssh key and save to `$Home\.ssh`
- Download and setup Qemu-Img
- Download my PowserShell scripts hyperv-k8s.ps1
- Run PowerShell as Admin and cd to folder having hyperv-k8s.ps1
- Run: .\hyperv-k8s.ps1 Get-Image
- Run: .\hyperv-k8s.ps1 Save-ISOMaster
- Run: .\hyperv-k8s.ps1 Save-ISONode1
✅Windows Admin center:
- Upload created isos (on Windows client) to `C:\Users\Administrator\Documents\isos`
- Upload hyperv-k8s.ps1 to `C:\Users\Administrator\Documents`
- Open PowersShell: 
- Run: .\hyperv-k8s.ps1 Install-Tools
- Run: .\hyperv-k8s.ps1 Deploy-HostsFile
- Run: .\hyperv-k8s.ps1 Deploy-Network
- Run: .\hyperv-k8s.ps1 Get-Image
- Run: .\hyperv-k8s.ps1 Deploy-Master
- Run: .\hyperv-k8s.ps1 Deploy-Node1
- Run: .\hyperv-k8s.ps1 Initialize-Kubeadm
- Run: .\hyperv-k8s.ps1 Start-KubeadmJoin
- Run: .\hyperv-k8s.ps1 Save-KubeConfig

