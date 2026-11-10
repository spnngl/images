# shellcheck shell=bash
# CIS (accounts_tmout): a shell left at its prompt for 15 min exits.
# Read-only, so no session turns it off. A running command isn't cut.
typeset -xr TMOUT=900
