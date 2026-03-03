#!/usr/bin/bash

CRON='0 18 * * *'

for f in *.yml; do
    echo "Update cron $f"
    sed -i "s/cron: '.*'/cron: '$CRON'/" $f;
done
