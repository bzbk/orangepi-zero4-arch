#!/bin/bash
# Show Orange Pi welcome page on interactive terminal (ssh / serial console)
[[ $- == *i* ]] || return 0
[[ -n $ORANGEPI_WELCOME_SHOWN ]] && return 0
export ORANGEPI_WELCOME_SHOWN=1
[[ -d /etc/update-motd.d ]] || return 0
for f in /etc/update-motd.d/*; do
    [[ -x "$f" ]] && "$f"
done
