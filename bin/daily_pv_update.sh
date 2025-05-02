#!/usr/bin/env bash

# This is a wrapper script, that coordinates the importer and passes a configurable database file to use.
#
# Homebrew needs an interactive shell, so in crontab export the display variable like this
# 30 0 * * * export DISPLAY=:0.0 && /pv/bin/daily_pv_update.sh
# Otherwise, there's also a plist file for Apples launchctl

set -euo pipefail
export LC_ALL=en_US.UTF-8

if [ -d "/opt/homebrew" ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)" eval "$(/opt/homebrew/bin/brew shellenv)"
fi

DIR="$(dirname "$(realpath "$0")")"
DB="$(< "$DIR"/../.secrets/prod_db)"

"$DIR"/import_and_update.sh "$DB"
