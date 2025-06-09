#!/bin/bash

processing_versions=$(cat processing_versions.txt | grep -Fvx -f processed_versions.txt)

for version in $processing_versions;do
	echo "processing version $version"
	./process_version.sh $version >/dev/null 2>&1 && echo $version >> processed_versions.txt
done
