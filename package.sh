#!/bin/bash

PLATFORM=$1
DISTRO=$2


if [[ "${PLATFORM}" == "pi" ]]; then
    OS="raspbian"
    ARCH="arm"
    PACKAGE_ARCH="armhf"
fi


PACKAGE_NAME=lifepoweredpi

TMPDIR=/tmp/${PACKAGE_NAME}-installdir
rm -rf ${TMPDIR}/*

mkdir -p ${TMPDIR} || exit 1
mkdir -p ${TMPDIR}/usr/local/include || exit 1
mkdir -p ${TMPDIR}/usr/local/lib || exit 1
mkdir -p ${TMPDIR}/usr/local/sbin || exit 1
mkdir -p ${TMPDIR}/usr/local/bin || exit 1
mkdir -p ${TMPDIR}/etc/init.d || exit 1


mkdir -p build/DAEMON
mkdir -p build/CLI
mkdir -p build/SO
gcc -c lifepo4wered-access.c -o build/DAEMON/lifepo4wered-access.o -std=c99 -Wall -O2
gcc -c lifepo4wered-data.c -o build/DAEMON/lifepo4wered-data.o -std=c99 -Wall -O2
gcc -c lifepo4wered-daemon.c -o build/DAEMON/lifepo4wered-daemon.o -std=c99 -Wall -O2
gcc -c lifepo4wered-access.c -o build/SO/lifepo4wered-access.o -std=c99 -Wall -O2 -fpic
gcc -c lifepo4wered-data.c -o build/SO/lifepo4wered-data.o -std=c99 -Wall -O2 -fpic
gcc -c lifepo4wered-access.c -o build/CLI/lifepo4wered-access.o -std=c99 -Wall -O2
gcc -c lifepo4wered-data.c -o build/CLI/lifepo4wered-data.o -std=c99 -Wall -O2
gcc -c lifepo4wered-cli.c -o build/CLI/lifepo4wered-cli.o -std=c99 -Wall -O2
gcc build/DAEMON/lifepo4wered-access.o build/DAEMON/lifepo4wered-data.o build/DAEMON/lifepo4wered-daemon.o -o build/DAEMON/lifepo4wered-daemon
gcc build/SO/lifepo4wered-access.o build/SO/lifepo4wered-data.o -o build/SO/liblifepo4wered.so -shared
gcc build/CLI/lifepo4wered-access.o build/CLI/lifepo4wered-data.o build/CLI/lifepo4wered-cli.o -o build/CLI/lifepo4wered-cli
cp lifepo4wered-data.h ${TMPDIR}/usr/local/include/

# Binary names
CLI_NAME=lifepo4wered-cli
DAEMON_NAME=lifepo4wered-daemon
SO_NAME=liblifepo4wered.so

# Install the shared object
install -p build/SO/$SO_NAME ${TMPDIR}/usr/local/lib
# Install the CLI
install -s -p build/CLI/$CLI_NAME ${TMPDIR}/usr/local/bin
# Install the daemon
install -s -p build/DAEMON/$DAEMON_NAME ${TMPDIR}/usr/local/sbin
# Install the init script
install -p -T initscript ${TMPDIR}/etc/init.d/$DAEMON_NAME

# Set the daemon directory in the init script
sed -i "s:DAEMON_DIRECTORY:/usr/local/sbin:" ${TMPDIR}/etc/init.d/$DAEMON_NAME



VERSION=$(git describe)

rm ${PACKAGE_NAME}_${VERSION//v}_${PACKAGE_ARCH}.deb > /dev/null 2>&1

fpm -a ${PACKAGE_ARCH} -s dir -t deb -n ${PACKAGE_NAME} -v ${VERSION//v} -C ${TMPDIR} \
  -p ${PACKAGE_NAME}_VERSION_ARCH.deb || exit 1

#
# Only push to cloudsmith for tags. If you don't want something to be pushed to the repo, 
# don't create a tag. You can build packages and test them locally without tagging.
#
git describe --exact-match HEAD > /dev/null 2>&1
if [[ $? -eq 0 ]]; then
    echo "Pushing package to OpenHD repository"
    cloudsmith push deb openhd/openhd/${OS}/${DISTRO} ${PACKAGE_NAME}_${VERSION//v}_${PACKAGE_ARCH}.deb
else
    echo "Not a tagged release, skipping push to OpenHD repository"
fi
