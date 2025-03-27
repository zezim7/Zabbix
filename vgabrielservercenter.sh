#!/bin/bash
##vgabrielservercenter.sh[{$HOST},{$SSH_USER},{$SSH_PASS}]
##----------------------------------------------------------------------------##
## Zabbix monitor vcenter server certificates.                                ##
##                                                                            ##
## Requirements:                                                              ##
##  * SSHPASS Instalado.                                                      ##
##  * User e Password adicionado zabbix  macro do host                        ##
##  * /usr/lib/zabbix/externalscripts/certificatemonitor.sh                   ##
##                                                                            ##
##                                                                            ##
## Created: 27 Fev 2025         Gabriel Lau                                   ##
##----------------------------------------------------------------------------##

if [ "$REMOTE_EXEC" != "1" ]; then
  if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <host> <ssh_user> <ssh_pass>"
    exit 3
  fi
  HOST="$1"
  SSH_USER="$2"
  SSH_PASS="$3"
  export REMOTE_EXEC=1
  sshpass -p "$SSH_PASS" ssh -o 'StrictHostKeyChecking=no' "$SSH_USER@$HOST" "export REMOTE_EXEC=1; bash -s" < "$0"
  exit $?
fi

output=$(
  for store in $(/usr/lib/vmware-vmafd/bin/vecs-cli store list | grep -v TRUSTED_ROOT_CRLS); do
    echo "[*] Store : $store"
    /usr/lib/vmware-vmafd/bin/vecs-cli entry list --store "$store" --text | grep -e "Alias" -e "Not After"
  done
)
current_date=$(date -u +"%b %d %T %Y GMT")
min_days=99999
closest_date=""
skip_entry=0
while IFS= read -r line; do
  if [[ $line == Alias* ]]; then
    if echo "$line" | grep -qi "bkp"; then
      skip_entry=1
    else
      skip_entry=0
    fi
  fi
  if [[ $line == *"Not After"* ]]; then
    if [ $skip_entry -eq 1 ]; then
      continue
    fi
    cert_date=$(echo "$line" | awk -F ' : ' '{print $2}')
    days_diff=$(( ( $(date -d "$cert_date" +%s) - $(date -d "$current_date" +%s) ) / 86400 ))
    if (( days_diff < min_days )); then
      min_days=$days_diff
      closest_date=$cert_date
    fi
  fi
done <<< "$output"
if (( min_days <= 7 )); then
  echo "1"
else
  echo "0"
fi
