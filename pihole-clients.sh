#!/bin/bash

## This script creates a Debian linux VM template on a Proxmox PVE server from a cloud image with secure boot support and some optional settings (which can be commented in or out as desire)d. Run as root, or change the working directory. 
## You should have admin rights on the Server.
## The script is convertible for creating a windows vm (or any non linux os), just get rid of the linux and cloudimage context, chanche the OS type and dont's convert into a template. In the case of using Windows you have to download and install the os after the vm is created.
## My requirements are:
## - debian linux
## - the latest image available
## - usefull for quickly creating a server for home use
## - a second harddrive to store the servers data (mainly docker related and configuration
## - secure boot support
## - apparmor
## - ready for configuring with ansible
## - a second network to separate management network and exposed services
## - some nice to have software

## set the variables (use descriptive names for clarity)

imageURL="https://cdimage.debian.org/images/cloud/trixie/daily/latest/debian-13-generic-amd64-daily.qcow2"
imageName="trixie-server-cloudimg-amd64.img"
volumeName="vmstorage0"
virtualMachineId="200"
templateName="pihole-clients-server"
tmp_cores="2"
tmp_memory="1024"
cpuTypeRequired="x86-64-v2-AES"
servicesNetwork="virtio,bridge=vmbr1"
osdriveSize="16G"
datadriveSize="16G"

## Set roothome as the working directory
cd /root

## Enforce the availability of libguestfs-tools for vm image manipulation on the pve server
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

## Create extra network for services
qm set $virtualMachineId --net1 $servicesNetwork

## Create the virtual harrdisk for the os
qm set $virtualMachineId --scsihw virtio-scsi-pci --scsi0 $volumeName:0,discard=on,ssd=1,format=qcow2,import-from=/root/trixie-server-cloudimg-amd64.img
qm disk resize $virtualMachineId scsi0 $osdriveSize

## Create the virtual harddrive for data
qm set $virtualMachineId --scsihw virtio-scsi-pci --scsi1 $volumeName:0,discard=on,ssd=1,format=qcow2
qm disk resize $virtualMachineId scsi1 $datadriveSize

## Import the cloud image to the VM
qm importdisk $virtualMachineId $imageName $volumeName

## Set the boot order
qm set $virtualMachineId --boot c --bootdisk scsi0

## Attach cloudinit to the VM
qm set $virtualMachineId --ide2 $volumeName:cloudinit

## Set the display mode
qm set $virtualMachineId --serial0 socket --vga serial0

## Set up the network to use dhcp (optional)
qm set $virtualMachineId --ipconfig0 ip=dhcp

## Set the cpu type
qm set $virtualMachineId --cpu cputype=$cpuTypeRequired

## Configure EFI for secureboot support (optional)
qm set $virtualMachineId --bios ovmf --efidisk0 $volumeName:1,format=qcow2,efitype=4m,pre-enrolled-keys=1

## Add a TPM v2.0 to the VM (optional for linux, mandatory for windows 11 support)
qm set $virtualMachineId -tpmstate0 $volumeName:1,version=v2.0

## Enable QEMU guest agent (optional)
qm set $virtualMachineId --agent enabled=1

## Convert the image to a template (optional in case you need just a vm)
# qm template $virtualMachineId
