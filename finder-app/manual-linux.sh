#!/bin/bash
# Script outline to install and build kernel.
# Author: Siddhant Jajoo.

set -e
set -u

OUTDIR=/tmp/aeld
KERNEL_REPO=git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
KERNEL_VERSION=v5.1.10
BUSYBOX_VERSION=1_33_1
FINDER_APP_DIR=$(realpath $(dirname $0))
ARCH=arm64
CROSS_COMPILE=aarch64-none-linux-gnu-
SYSROOT=$(${CROSS_COMPILE}gcc -print-sysroot)
SCRIPTDIR=$(dirname "$(pwd)/${0}")


if [ $# -lt 1 ]
then
	echo "Using default directory ${OUTDIR} for output"
else
	OUTDIR=$1
	echo "Using passed directory ${OUTDIR} for output"
fi

mkdir -p ${OUTDIR}

if [ $? -ne 0 ]
then
    echo "Could not create the dirictory!"
    exit 1
fi

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/linux-stable" ]; then
    #Clone only if the repository does not exist.
	echo "CLONING GIT LINUX STABLE VERSION ${KERNEL_VERSION} IN ${OUTDIR}"
	git clone ${KERNEL_REPO} --depth 1 --single-branch --branch ${KERNEL_VERSION}
fi
if [ ! -e ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ]; then
    cd linux-stable
    echo "Checking out version ${KERNEL_VERSION}"
    git checkout ${KERNEL_VERSION}

    # building the kernel, the modules, and the dtb, but first proper cleaning
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} mrproper
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} defconfig

    # yylloc & treesource_error should be decleard as extern, otherwith there will be linking errors
    # sed -i 's/^YYLTYPE yylloc;/extern YYLTYPE yylloc;/' linux-stable/scripts/dtc/dtc-lexer.lex.c
    # sed -i 's/^bool treesource_error;/extern bool treesource_error;/' linux-stable/scripts/dtc/dtc-lexer.lex.c
    
    make -j4 ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} all
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} modules
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} dtbs
fi

echo "Adding the Image in outdir"
cp "${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image" "${OUTDIR}"

echo "Creating the staging directory for the root filesystem"
cd "$OUTDIR"
if [ -d "${OUTDIR}/rootfs" ]
then
    echo "Deleting rootfs directory at ${OUTDIR}/rootfs and starting over"
    sudo rm  -rf ${OUTDIR}/rootfs
fi

mkdir ${OUTDIR}/rootfs
cd ${OUTDIR}/rootfs
mkdir bin dev etc home lib proc sbin sys tmp usr var
ln -s lib lib64
ln -s ../lib usr/lib 
mkdir usr/bin usr/sbin
mkdir -p var/log


# Create necessary base directories
cd "$OUTDIR"
if [ ! -d "${OUTDIR}/busybox" ]
then
    git clone git://busybox.net/busybox.git
    cd busybox
    git checkout ${BUSYBOX_VERSION}
    make distclean
    make defconfig
else
    cd busybox
fi


# TODO: Make and install busybox
make CONFIG_PREFIX=${OUTDIR}/rootfs ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE}
make CONFIG_PREFIX=${OUTDIR}/rootfs ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} install

BUSYBOXEXEC=$(find ${OUTDIR}/busybox -type f -executable -name "busybox")

echo "Library dependencies"
${CROSS_COMPILE}readelf -a $BUSYBOXEXEC | grep "program interpreter"
${CROSS_COMPILE}readelf -a $BUSYBOXEXEC | grep "Shared library"


# Add library dependencies to rootfs
INTERPRETER=$(${CROSS_COMPILE}readelf -a $BUSYBOXEXEC | grep "program interpreter" | cut -d ":" -f2 | cut -d "]" -f1)
SHAREDLIBS=$(${CROSS_COMPILE}readelf -a $BUSYBOXEXEC | grep "Shared library" | cut -d "[" -f2 | cut -d "]" -f1)
ALLLIBS="$INTERPRETER $SHAREDLIBS"

for LIB in $ALLLIBS;
do
    LIB=$(find $SYSROOT -name "$(basename $LIB)" | sed -r 's/ //g')
    REALLIB=$(readlink -f $LIB | sed -r 's/ //g')
    cp -an ${LIB} ${REALLIB} "${OUTDIR}/rootfs/lib/"
done


# TODO: Make device nodes
sudo mknod -m 666 ${OUTDIR}/rootfs/dev/null c 1 3
sudo mknod -m 600 ${OUTDIR}/rootfs/dev/console c 5 1


# Clean and build the writer utility 
cd $SCRIPTDIR
make clean
make CROSS_COMPILE=${CROSS_COMPILE}


# Copy the finder related scripts and executables to the /home directory
cd $SCRIPTDIR
cp -a ./ ${OUTDIR}/rootfs/home
cp -ar ../conf ${OUTDIR}/rootfs/conf


# on the target rootfs, Chown the root directory and Create initramfs.cpio.gz
cd ${OUTDIR}/rootfs
find . | cpio -H newc -ov --owner root:root > ../initramfs.cpio
cd ..
rm -f initramfs.cpio.gz
gzip initramfs.cpio
# mkimage -A arm -O linux -T ramdisk -d initramfs.cpio.gz uRamdisk
