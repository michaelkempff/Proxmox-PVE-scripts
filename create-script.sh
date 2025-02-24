#!/bin/bash

## This script creates a Debian Linux VM or VM template on a Proxmox PVE server. I'm mainly using Debian Cloud images, and some optional settings (which can be commented in or out as desired). 
## Run as root, or change the working directory. 
## You should have admin rights on the Server.
## The structure is mainly inspired by: https://github.com/andrewglass3/ProxmoxCloudInitScript
## My requirements are:
## - Debian Linux
## - The latest image available
## - Usefull for quickly creating a server for home use
## - A second harddrive to store the servers data as needed
## - Secure boot support
## - Apparmor
## - Ready for configuring with Ansible
## - Multiple VLAN's to separate management network and services
## - Some nice to have software I like to have on any server I create

## Set the variables (use descriptive names for clarity)

imageURL="https://cdimage.debian.org/images/cloud/trixie/daily/latest/debian-13-generic-amd64-daily.qcow2" ## Latest version of Debian 13, feel free to use another linux cloud image
imageName="trixie-server-cloudimg-amd64.img" ## Image name to refer to in this script
volumeName="vmstorage0" ## Storage volume on the host
virtualMachineId="100" ## Unique id number for VM
templateName="service_name-server" ## Name for the template or VM
tmp_cores="2" ## Number of CPU cores
tmp_memory="1024" ## RAM in MB
cpuTypeRequired="x86-64-v2-AES" ## Set the cpu type
secondNetwork="virtio,bridge=vmbr4"  ## Set the second network, optional, comment out variable and corresponding commands to disable (all servers default to vmbr0 as first network net0)
# thirdNetwork="virtio,bridge=vmbr5" ## Set the third network, very optional, comment out variable and corresponding commands to disable
# fourthNetwork="virtio,bridge=vmbr5" ## Set the fourth network, very optional, comment out variable and corresponding commands to disable
# fifthNetwork="virtio,bridge=vmbr5" ## Set the fifth network, very optional, comment out variable and corresponding commands to disable
osdriveSize="16G" ## Set the os drive size
datadriveSize="16G" ## Set the size for the data volume, optional, comment out variable and corresponding command(s) to disable
# pcieDeviceid="0000:14:00.0" ## Set the pcie id for a device to passthrough to the guest, very optional, comment out variable and corresponding command(s) to disable

## Set roothome as the working directory
cd /root

## Enforce the availability of libguestfs-tools for VM image manipulation on the PVE server
apt update
apt install libguestfs-tools -y

## Remove all old img files (optional but recommended)
rm *.img

## Download the cloud image
wget -O $imageName $imageURL

## Ensure the virtualMachineId is not in use
qm destroy $virtualMachineId

## Install aditional software (eventualy convert this lines to ansible or in a variable in the future)
virt-customize -a $imageName --install qemu-guest-agent
virt-customize -a $imageName --install htop
virt-customize -a $imageName --install iotop
virt-customize -a $imageName --install strace
virt-customize -a $imageName --install lsof
virt-customize -a $imageName --install mc
virt-customize -a $imageName --install auditd
virt-customize -a $imageName --install apparmor-utils
virt-customize -a $imageName --install apparmor-profiles
virt-customize -a $imageName --install ansible

## Create the VM
qm create $virtualMachineId --name $templateName --memory $tmp_memory --ostype l26 --sockets 1 --cores $tmp_cores --net0 virtio,bridge=vmbr0 --machine q35

## Create extra network for services (optional)
qm set $virtualMachineId --net1 $secondNetwork

## Create extra network (very optional)
# qm set $virtualMachineId --net2 $thirdNetwork

## Create extra network (very optional)
# qm set $virtualMachineId --net2 $fourthNetwork

## Create extra network (very optional)
# qm set $virtualMachineId --net2 $fifthNetwork

## Create the virtual harddisk for the os
qm set $virtualMachineId --scsihw virtio-scsi-pci --scsi0 $volumeName:0,discard=on,ssd=1,format=qcow2,import-from=/root/trixie-server-cloudimg-amd64.img
qm disk resize $virtualMachineId scsi0 $osdriveSize

## Create the virtual harddrisk for data (optional)
qm set $virtualMachineId --scsihw virtio-scsi-pci --scsi1 $volumeName:0,discard=on,ssd=1,format=qcow2
qm disk resize $virtualMachineId scsi1 $datadriveSize

## Import the cloud image to the VM
qm importdisk $virtualMachineId $imageName $volumeName:0

## Set the boot order
qm set $virtualMachineId --boot c --bootdisk scsi0

## Attach cloudinit to the VM
qm set $virtualMachineId --ide2 $volumeName:cloudinit

## Set the display mode
qm set $virtualMachineId --serial0 socket --vga serial0

## Set up the primary network to use dhcp (no dhcp for a server)
# qm set $virtualMachineId --ipconfig0 ip=dhcp

## Set the cpu type
qm set $virtualMachineId --cpu cputype=$cpuTypeRequired

## Configure EFI for secureboot support (optional)
qm set $virtualMachineId --bios ovmf --efidisk0 $volumeName:1,format=qcow2,efitype=4m,pre-enrolled-keys=1

## Add a TPM v2.0 to the VM (optional for linux, mandatory for windows 11 support)
qm set $virtualMachineId -tpmstate0 $volumeName:1,version=v2.0

## Enable QEMU guest agent (optional)
qm set $virtualMachineId --agent enabled=1

## Passtrhough pcie device to the guest (very optional)
# qm set $virtualMachineId -hostpci0 $pcieDeviceid.0,pcie=on

## Convert the image to a template (optional in case you just need a vm)
# qm template $virtualMachineId
