#!/bin/bash

PWD=`pwd`
TOP=${PWD}

BUILD_TYPE=RELEASE
GCC_DIR=${PWD}/gcc/
ATF_DIR=${PWD}/atf/
MV_DDR_DIR=${PWD}/mv_ddr/
EDK2_DIR=${PWD}/edk2/
EDK2_PLATFORM_DIR=${PWD}/OpenPlatformPkg/
UBOOT_DIR=${PWD}/uboot/
PM_DIR=${PWD}/pm/

GCC_RELEASE=gcc-linaro-5.3.1-2016.05-x86_64_aarch64-linux-gnu
GCC_FILE=${GCC_RELEASE}.tar.xz
GCC_URL=https://releases.linaro.org/components/toolchain/binaries/5.3-2016.05/aarch64-linux-gnu/${GCC_FILE}

EDK2_REPO=https://github.com/tianocore/edk2
EDK2_PLATFORM_REPO=https://github.com/MarvellEmbeddedProcessors/edk2-open-platform.git
EDK2_PLATFORM_BRANCH=marvell-armada-wip

ATF_REPO=https://github.com/MarvellEmbeddedProcessors/atf-marvell.git
ATF_BRANCH=atf-v1.3-armada-17.06

MV_DDR_REPO=https://github.com/MarvellEmbeddedProcessors/mv-ddr-marvell.git
MV_DDR_BRANCH=mv_ddr-armada-17.06

UBOOT_REPO=https://github.com/MarvellEmbeddedProcessors/u-boot-marvell
UBOOT_BRANCH=u-boot-2017.03-armada-17.06

PM_URL=http://wiki.macchiatobin.net/tiki-download_file.php?fileId=28
PM_BINARY=RTOSDemo-cm3.bin

### Power Mangament binary
if [ ! -d "${PM_DIR}" ]; then
    # Install cross-compiler
    mkdir -p "${PM_DIR}"
fi

if [ ! -e "${PM_DIR}/${PM_BINARY}" ]; then
	wget -c "${PM_URL}" -o "${PM_DIR}/${PM_BINARY}"
fi
export SCP_BL2="${PM_DIR}/${PM_BINARY}"

### GCC
if [ ! -d "${GCC_DIR}" ]; then
    # Install cross-compiler
    mkdir -p "${GCC_DIR}"
fi

cd "${GCC_DIR}"
if [ ! -d "${GCC_RELEASE}/bin" ]; then
    wget -c "${GCC_URL}"
    tar -xf "${GCC_FILE}" -C .
fi

export GCC5_AARCH64_PREFIX="${GCC_DIR}/${GCC_RELEASE}/bin/aarch64-linux-gnu-"

### Check out latest EDK2 Source code
if [ ! -d "${EDK2_DIR}" ]; then
    mkdir -p "${EDK2_DIR}"
fi

cd "${EDK2_DIR}"
if [ ! -d ".git" ]; then
    git clone "${EDK2_REPO}" .
fi
git pull -q

### EDK2 OpenPlatformPkg
if [ ! -d "${EDK2_PLATFORM_DIR}" ]; then
    mkdir -p "${EDK2_PLATFORM_DIR}"
fi

cd "${EDK2_PLATFORM_DIR}"
if [ ! -d ".git" ]; then
    git clone "${EDK2_PLATFORM_REPO}" .
fi

branch=$(git branch | sed -n -e 's/^\* \(.*\)/\1/p')
git pull -q

if [[ "${branch}" != ${EDK2_PLATFORM_BRANCH} ]]; then
    git checkout -b ${EDK2_PLATFORM_BRANCH} origin/${EDK2_PLATFORM_BRANCH}
fi

if [ ! -e "${EDK2_DIR}/OpenPlatformPkg" ]; then
    ln -s "${EDK2_PLATFORM_DIR}" "${EDK2_DIR}/OpenPlatformPkg"
fi

### Compile EDK2
cd ${EDK2_DIR}
make -C BaseTools
source edksetup.sh

build -a AARCH64 -t GCC5 -b ${BUILD_TYPE} -p OpenPlatformPkg/Platforms/Marvell/Armada/Armada80x0McBin.dsc

export BL33=${EDK2_DIR}/Build/Armada80x0McBin-AARCH64/${BUILD_TYPE}_GCC5/FV/ARMADA_EFI.fd


export CROSS_COMPILE=${GCC5_AARCH64_PREFIX=}
export ARCH=arm64

### Checkout ATF
if [ ! -d "${ATF_DIR}" ]; then
    mkdir -p "${ATF_DIR}"
fi

cd "${ATF_DIR}"
if [ ! -d ".git" ]; then
    git clone "${ATF_REPO}" .
fi

branch=$(git branch | sed -n -e 's/^\* \(.*\)/\1/p')
git pull -q

if [[ "${branch}" != ${ATF_BRANCH} ]]; then
    git checkout -b ${ATF_BRANCH} origin/${ATF_BRANCH}
fi

### Checkout MV_DDR
if [ ! -d "${MV_DDR_DIR}" ]; then
    mkdir -p "${MV_DDR_DIR}"
fi

cd "${MV_DDR_DIR}"
if [ ! -d ".git" ]; then
    git clone "${MV_DDR_REPO}" .
fi

branch=$(git branch | sed -n -e 's/^\* \(.*\)/\1/p')
git pull -q

if [[ "${branch}" != ${MV_DDR_BRANCH} ]]; then
    git checkout -b ${MV_DDR_BRANCH} origin/${MV_DDR_BRANCH}
fi

### Build ATF
cd "${ATF_DIR}"
make clean
make USE_COHERENT_MEM=0 LOG_LEVEL=20 MV_DDR_PATH="${MV_DDR_DIR}" PLAT=a80x0_mcbin all fip

cp "${ATF_DIR}/build/a80x0_mcbin/release/flash-image.bin" "${TOP}/edk2-flash-image.bin"


### Checkout u-boot
if [ ! -d "${UBOOT_DIR}" ]; then
    mkdir -p "${UBOOT_DIR}"
fi

cd "${UBOOT_DIR}"
if [ ! -d ".git" ]; then
    git clone "${UBOOT_REPO}" .
fi

branch=$(git branch | sed -n -e 's/^\* \(.*\)/\1/p')
git pull -q

if [[ "${branch}" != ${UBOOT_BRANCH} ]]; then
    git checkout -b ${UBOOT_BRANCH} origin/${UBOOT_BRANCH}
fi

cd "${UBOOT_DIR}"
make mvebu_mcbin-88f8040_defconfig
make
ls u-boot*

export BL33="${UBOOT_DIR}/u-boot.bin"

cd "${ATF_DIR}"
make clean
make USE_COHERENT_MEM=0 LOG_LEVEL=20 MV_DDR_PATH="${MV_DDR_DIR}" PLAT=a80x0_mcbin all fip

cp "${ATF_DIR}"/build/a80x0_mcbin/release/flash-image.bin "${TOP}/u-boot-flash-image.bin"
ls -al "${TOP}/"*flash-image.bin
