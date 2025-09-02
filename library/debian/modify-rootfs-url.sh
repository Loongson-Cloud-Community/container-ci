#!/bin/bash

set -u
set -e

rootfs="$1"
snapshotUrl="$2"

rootfsDir=$(dirname $(readlink -f $rootfs))
modifyDir=$(mktemp -d)

tar -xf $rootfs -C $modifyDir

pushd $modifyDir
sed -i -e "s|^\(URIs:\).*|\1 $snapshotUrl|g" $modifyDir/etc/apt/sources.list.d/debian.sources
# 解决 snapshot 源过期的问题
echo 'Acquire::Check-Valid-Until "false";' > $modifyDir/etc/apt/apt.conf.d/99ignore-valid-until
touch rootfs.tar.xz
tar --exclude=rootfs.tar.xz -Jcvf rootfs.tar.xz -C $modifyDir .
popd

rm -f $rootfsDir/rootfs.tar.xz
mv $modifyDir/rootfs.tar.xz $rootfsDir/
