variable "base_image" {
  type = string
}

variable "ssh_key_file" {
  type = string
}

variable "errata" {
  type = string
}

variable "sp" {
  type    = string
  default = "y"
}

variable "release" {
  type = string
}

variable "errata_url" {
  type = string
}

variable "patches_path" {
  type = string
}

variable "config_path" {
  type = string
}

variable "drivers" {
  type = string
}

source "qemu" "builder" {
  vm_name          = "builder-${var.build}-${var.arch}-aws-kernel.qcow2"
  output_directory = "output/builder/${var.build}-${var.arch}"

  disk_image       = true
  use_backing_file = true
  iso_checksum     = "none"
  iso_url          = var.base_image

  qemu_binary       = local.qemu_binary[var.arch]
  machine_type      = local.machine_type[var.arch]
  efi_firmware_code = local.use_efi ? var.efi_code : ""
  efi_firmware_vars = local.use_efi ? var.efi_vars : ""
  qemuargs          = local.qemuargs[var.arch]
  accelerator       = var.accelerator
  disk_interface    = local.use_efi ? "virtio-scsi" : "virtio"
  cpus              = 4
  memory            = 4096
  headless          = true
  format            = "qcow2"

  shutdown_command = "halt -p"

  ssh_private_key_file = var.ssh_key_file
  ssh_username         = "root"
  ssh_timeout          = "20m"
}

build {
  sources = ["source.qemu.builder"]

  provisioner "file" {
    source      = "scripts"
    destination = "/home"
  }

  provisioner "file" {
    source      = "patches"
    destination = "/home"
  }

  provisioner "file" {
    source      = "config"
    destination = "/home"
  }

  provisioner "file" {
    source      = "keys"
    destination = "/home"
  }

  provisioner "shell" {
    inline = [
      "ksh /home/scripts/build.sh ${var.release} ${var.arch} ${var.errata} ${var.sp} ${var.errata_url} /home/${var.patches_path} /home/${var.config_path} /home/${var.signify_key} '${var.drivers}'",
    ]
  }

  provisioner "shell-local" {
    inline = [
      "mkdir -p output/bundles",
    ]
  }

  provisioner "file" {
    direction   = "download"
    source      = "/home/${var.release}.tgz"
    destination = "output/bundles/${var.release}.tgz"
  }

  provisioner "file" {
    direction   = "download"
    source      = "/home/${var.release}.tgz.SHA256"
    destination = "output/bundles/${var.release}.tgz.SHA256"
  }
}
