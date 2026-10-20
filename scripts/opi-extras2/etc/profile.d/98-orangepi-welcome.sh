#!/bin/bash
# Display Orange Pi MOTD on interactive login (ssh / serial console)
[[ $- == *i* ]] || return 0
[[ -n $ORANGEPI_WELCOME_SHOWN ]] && return 0
export ORANGEPI_WELCOME_SHOWN=1
for f in /etc/update-motd.d/[0-9]*; do
    [[ -f "$f" ]] || continue
    bash "$f"
done
