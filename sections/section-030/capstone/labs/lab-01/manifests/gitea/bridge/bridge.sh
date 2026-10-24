#!/bin/sh
# Prints the status line of the bridge service for one crew member.
set -eu

crew="${1:-bridge}"
printf 'Bridge online for %s\n' "$crew"
