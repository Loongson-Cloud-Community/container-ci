#!/bin/bash

set -u
set -e
set -x

rootfs="$1"
snapshotUrl="$2"

rootfsDir=$(dirname $(readlink -f $rootfs))
modifyDir=$(mktemp -d)

tar -xf $rootfs -C $modifyDir

pushd $modifyDir
sed -i -e "s|^\(URIs:\).*|\1 $snapshotUrl|g" $modifyDir/etc/apt/sources.list.d/debian.sources
touch rootfs.tar.xz
tar --exclude=rootfs.tar.xz -Jcvf rootfs.tar.xz -C $modifyDir .
popd

rm -f $rootfsDir/rootfs.tar.xz
mv $modifyDir/rootfs.tar.xz $rootfsDir/
