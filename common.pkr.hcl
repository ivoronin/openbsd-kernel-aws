packer {
  required_plugins {
    qemu = {
      version = "1.1.5"
      source  = "github.com/hashicorp/qemu"
    }
    sshkey = {
      version = "1.3.0"
      source  = "github.com/ivoronin/sshkey"
    }
  }
}

variable "build" {
  type = string
}

variable "arch" {
  type = string
}

variable "accelerator" {
  type = string
}

variable "efi_code" {
  type    = string
  default = ""
}

variable "efi_vars" {
  type    = string
  default = ""
}

variable "signify_key" {
  type = string
}

locals {
  use_efi = var.arch == "arm64"
  qemu_binary = {
    amd64 = "qemu-system-x86_64"
    arm64 = "qemu-system-aarch64"
  }
  machine_type = {
    amd64 = "pc"
    arm64 = "virt"
  }
  qemuargs = {
    amd64 = []
    arm64 = [
      ["-cpu", var.accelerator == "tcg" ? "cortex-a72" : "host"],
      ["-device", "virtio-gpu-pci"],
      ["-device", "qemu-xhci"],
      ["-device", "usb-kbd"],
      ["-device", "virtio-scsi-pci,id=scsi0"],
      ["-device", "scsi-hd,bus=scsi0.0,drive=drive0,bootindex=0"],
    ]
  }
}
