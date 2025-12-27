#!/bin/bash

PROGNAME=$(basename "$0")

rsync_cmd=(rsync -avh --mkpath --progress --stats)

usage() {
  echo 'Copy or Move files using Rsync.'
  echo "Usage: $PROGNAME [option] [Sources] [Destination]"
  cat <<_EOF_

  -c		copy files
  -m		move files
  --check   check files using rsync checksum after copying
_EOF_
  exit
}

while :; do
  case "$1" in
  -c)
    copy_files=1
    shift
    ;;
  -m)
    copy_files=0
    shift
    ;;
  --check)
    integrity_check=1
    shift
    ;;
  --)
    shift
    break
    ;;
  -?*)
    usage
    ;;
  *) break ;;
  esac
done

#Only send notifications if notify-send present
if command -v notify-send &>/dev/null; then
  notify_send_present=0
else
  notify_send_present=1
fi

run_notify() {
  if [[ $notify_send_present -eq 0 ]]; then
    /usr/bin/notify-send -u critical -t 0 "$1" "$2" --icon=dialog-information
  fi
}

ARGARR=("$@")
LENARG=${#ARGARR[@]}

if [[ "$LENARG" -lt 2 ]]; then
  usage
fi

OFILE="${ARGARR[-1]}"
unset 'ARGARR[-1]'

check_integrity() {
  if [[ $1 -eq 0 && $integrity_check ]]; then
    sync
    echo -e "\n\033[32mRunning an rsync checksum check\033[0m\n"
    rsync -ah --itemize-changes --checksum "${ARGARR[@]}" "$OFILE"
    exit_code="$?"
    run_notify 'File integrity check done' "Exit Code $exit_code"
  fi
}

"${rsync_cmd[@]}" "${ARGARR[@]}" "$OFILE"
exit_code="$?"
check_integrity "$exit_code"
if [[ $exit_code -ne 0 ]]; then
  run_notify 'Rsync Failed' "Exit Code $exit_code"
  exit $exit_code
fi

if [[ $copy_files -eq 1 ]]; then
  run_notify 'File Copy Done' "Exit Code $exit_code"
else
  #Remove source files with rsync.
  sync
  rsync -ah --remove-source-files "${ARGARR[@]}" "$OFILE"
  exit_code="$?"
  if [[ $exit_code -eq 0 ]]; then
    run_notify 'File Move Success' "Exit Code $exit_code"
    #Remove empty dirs with find to simulate move
    for i in "${ARGARR[@]}"; do
      if [[ "$i" == */ ]]; then
        find "$i" -mindepth 1 -type d -empty -delete 2> >(grep -v 'No such file' >&2)
      else
        find "$i" -type d -empty -delete 2> >(grep -v 'No such file' >&2)
      fi
    done
  else
    run_notify 'File Move Failed' "Exit Code $exit_code"
  fi
fi
#Preserve original exit code
(exit $exit_code)
