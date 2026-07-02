variable "iso_checksum" {
  type = string
}

variable "iso_url" {
  type = string
}

variable "iso_sets_path" {
  type = string
}

variable "source_url" {
  type = string
}

data "sshkey" "builder" {
  type = "ed25519"
}

locals {
  base_dir = "output/builder-base/${var.build}-${var.arch}"
  install_qemuargs = {
    amd64 = []
    arm64 = concat(local.qemuargs["arm64"], [
      ["-device", "scsi-cd,bus=scsi0.0,drive=cdrom0,bootindex=1"],
    ])
  }
}

source "qemu" "prepare" {
  vm_name          = "base.qcow2"
  output_directory = local.base_dir

  iso_checksum    = var.iso_checksum
  iso_url         = var.iso_url
  iso_target_path = "iso/openbsd-${var.build}-${var.arch}.iso"

  http_content = {
    "/install.conf" = templatefile("build.conf.pkrtpl", {
      "ssh_public_key" : data.sshkey.builder.public_key,
      "disk_answer" : local.use_efi ? "G" : "W",
      "iso_sets_path" : var.iso_sets_path,
    })
  }

  qemu_binary       = local.qemu_binary[var.arch]
  machine_type      = local.machine_type[var.arch]
  efi_firmware_code = local.use_efi ? var.efi_code : ""
  efi_firmware_vars = local.use_efi ? var.efi_vars : ""
  qemuargs          = local.install_qemuargs[var.arch]
  accelerator       = var.accelerator
  disk_size         = "40G"
  disk_interface    = local.use_efi ? "virtio-scsi" : "virtio"
  cdrom_interface   = local.use_efi ? "virtio-scsi" : ""
  cpus              = 4
  memory            = 4096
  headless          = true
  format            = "qcow2"

  boot_command = [
    "A<enter><wait>",
    "http://{{ .HTTPIP }}:{{ .HTTPPort }}/install.conf<enter>",
  ]
  boot_wait        = var.accelerator == "tcg" ? "180s" : "90s"
  shutdown_command = "halt -p"

  ssh_private_key_file = data.sshkey.builder.private_key_path
  ssh_username         = "root"
  ssh_timeout          = "20m"
}

build {
  sources = ["source.qemu.prepare"]

  provisioner "file" {
    source      = "scripts"
    destination = "/home"
  }

  provisioner "file" {
    source      = "keys"
    destination = "/home"
  }

  provisioner "shell" {
    inline = [
      "ksh /home/scripts/prepare.sh ${var.source_url} /home/${var.signify_key}",
    ]
  }

  provisioner "shell-local" {
    inline = [
      "cp ${data.sshkey.builder.private_key_path} ${local.base_dir}/sshkey",
      "chmod 600 ${local.base_dir}/sshkey",
    ]
  }
}
