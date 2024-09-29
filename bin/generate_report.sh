#!/usr/bin/env bash

set -euo pipefail
export LC_ALL=en_US.UTF-8

DIR="$(dirname "$(realpath "$0")")"

TARGET="$(< $DIR/../.secrets/target)"

(source $DIR/../notebooks/.venv/bin/activate && jupyter nbconvert --execute --to html --output index.html --no-input Photovoltaik\ \|\ Familie\ Simons,\ Aachen.ipynb && scp index.html $TARGET && rm index.html)
