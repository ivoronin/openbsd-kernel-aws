BUILDS = $(sort $(patsubst builds/%.mk,%,$(wildcard builds/*.mk)))

HOST_ARCH := $(patsubst aarch64,arm64,$(patsubst x86_64,amd64,$(shell uname -m)))
# newest OpenBSD version manifest
BUILD ?= $(lastword $(BUILDS))
ARCH ?= $(HOST_ARCH)
BUILD_MANIFEST = builds/$(BUILD).mk

include $(BUILD_MANIFEST)

ISO_CHECKSUM = $(ISO_CHECKSUM.$(ARCH))
ISO_URL = $(ISO_URL.$(ARCH))
ISO_SETS_PATH = $(ISO_SETS_PATH.$(ARCH))
CONFIG_PATH = $(CONFIG_PATH.$(ARCH))

ifeq ($(ISO_URL),)
$(error $(BUILD_MANIFEST): missing ISO_URL.$(ARCH))
endif

ERRATA ?= 000
SP ?= y
ACCELERATOR ?= $(if $(filter $(ARCH),$(HOST_ARCH)),$(if $(filter Darwin,$(shell uname -s)),hvf,kvm),tcg)
EFI_CODE ?= $(firstword $(wildcard $(if $(filter arm64,$(ARCH)),\
/opt/homebrew/share/qemu/edk2-aarch64-code.fd /usr/share/qemu/edk2-aarch64-code.fd /usr/share/AAVMF/AAVMF_CODE.fd,\
/opt/homebrew/share/qemu/edk2-x86_64-code.fd /usr/share/qemu/edk2-x86_64-code.fd /usr/share/OVMF/OVMF_CODE_4M.fd /usr/share/OVMF/OVMF_CODE.fd)))
EFI_VARS ?= $(firstword $(wildcard $(if $(filter arm64,$(ARCH)),\
/opt/homebrew/share/qemu/edk2-arm-vars.fd /usr/share/qemu/edk2-arm-vars.fd /usr/share/AAVMF/AAVMF_VARS.fd,\
/opt/homebrew/share/qemu/edk2-i386-vars.fd /usr/share/qemu/edk2-i386-vars.fd /usr/share/OVMF/OVMF_VARS_4M.fd /usr/share/OVMF/OVMF_VARS.fd)))
RELEASE ?= $(BUILD)-$(ARCH)-dev

BASE_DIR = output/builder-base/$(BUILD)-$(ARCH)
BASE_IMAGE = $(BASE_DIR)/base.qcow2
BASE_KEY = $(BASE_DIR)/sshkey

.PHONY: errata prepare build cache-key lint test clean distclean
.SUFFIXES:
.DEFAULT_GOAL := build

errata:
	@perl scripts/errata-level.pl '$(ERRATA_URL)' '$(SIGNIFY_KEY)'

cache-key:
	@printf '%s-' '$(ISO_CHECKSUM)' | tr ':' '-'
	@cat build.conf.pkrtpl scripts/prepare.sh | openssl dgst -sha256 -r | cut -c1-12

PACKER_VARS = \
	  -var build=$(BUILD) \
	  -var arch=$(ARCH) \
	  -var iso_checksum=$(ISO_CHECKSUM) \
	  -var iso_url=$(ISO_URL) \
	  -var iso_sets_path=$(ISO_SETS_PATH) \
	  -var source_url=$(SOURCE_URL) \
	  -var base_image=$(BASE_IMAGE) \
	  -var ssh_key_file=$(BASE_KEY) \
	  -var accelerator=$(ACCELERATOR) \
	  -var efi_code=$(EFI_CODE) \
	  -var efi_vars=$(EFI_VARS) \
	  -var errata=$(ERRATA) \
	  -var sp=$(SP) \
	  -var release=$(RELEASE) \
	  -var errata_url=$(ERRATA_URL) \
	  -var patches_path=$(PATCHES_PATH) \
	  -var config_path=$(CONFIG_PATH) \
	  -var signify_key=$(SIGNIFY_KEY) \
	  -var 'drivers=$(DRIVERS)'

prepare:
	packer init .
	packer build -force -only=qemu.prepare $(PACKER_VARS) .

$(BASE_IMAGE):
	$(MAKE) prepare

build: $(BASE_IMAGE)
	packer init .
	packer build -force -only=qemu.builder $(PACKER_VARS) .

lint:
	shellcheck scripts/build.sh scripts/install.sh scripts/prepare.sh
	perl -c scripts/errata-level.pl
	perl -c scripts/build-matrix.pl

test:
	prove -q t/*.t

clean:
	rm -rf output/builder output/bundles

distclean:
	rm -rf output iso
