name: '{{ .org }}::{{ .repo }}'

on:
    schedule:
        - cron: '{{ .cron }}'
    workflow_dispatch:

jobs:
    ci:
      if: github.repository == 'Loongson-Cloud-Community/release-ci'
      runs-on: self-hosted
      steps:
          - name: Checkout Code
            uses: actions/checkout@v3

          - name: Run ci.sh
            run: |
              date
              pushd {{ .org }}/{{ .repo }} && ./ci.sh && pop
