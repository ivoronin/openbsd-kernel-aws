SOURCE_URL = https://cdn.openbsd.org/pub/OpenBSD/7.9
ERRATA_URL = https://cdn.openbsd.org/pub/OpenBSD/patches/7.9/common
PATCHES_PATH = patches/79
SIGNIFY_KEY = keys/openbsd-79-base.pub
DRIVERS = \
	https://github.com/ivoronin/openbsd-driver-ena@6cdcedad22285145318c198472fb31a3157efe81:src \
	https://github.com/ivoronin/openbsd-driver-plgpio-acpi@fe8de2ce32076d36c88678fd0cd14e99d8dad831:src

ISO_CHECKSUM.amd64 = sha256:7a4a92e953618035097c796a90b54424a0f3ae775552e1e7d102cf8a5130449f
ISO_URL.amd64 = https://cdn.openbsd.org/pub/OpenBSD/7.9/amd64/install79.iso
ISO_SETS_PATH.amd64 = 7.9/amd64
CONFIG_PATH.amd64 = config/79/amd64/AWS

ISO_CHECKSUM.arm64 = sha256:49786ab82868b6e508a0117c0c1567694a2f6b46caf8972c726868617b8c22fb
ISO_URL.arm64 = https://cdn.openbsd.org/pub/OpenBSD/7.9/arm64/install79.iso
ISO_SETS_PATH.arm64 = 7.9/arm64
CONFIG_PATH.arm64 = config/79/arm64/AWS
