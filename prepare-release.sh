#!/bin/sh

base=btrfsmaintenance
version=$(grep -i ^version: ${base}.spec | awk '{print $2}')
tardir="${base}-${version}"

rm -rf "$tardir"
mkdir "$tardir"
cp *.py $tardir
cp *.sh $tardir
cp *.service $tardir
cp *.template $tardir
cp sysconfig.* $tardir
cp COPYING $tardir
cp README.* $tardir
rm $tardir/$(basename $0)

tar cvjf "$tardir".tar.bz2 "$tardir"
