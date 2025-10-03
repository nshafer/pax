#!/bin/bash

# This script updates the packaged Font Awesome files in priv/static. It downloads the latest zip file from
# the Font Awesome website, extracts it to a temporary directory, and copies the relevant CSS and webfont files
#
# Usage:
#
#     ./bin/update_fa.sh
#     mix phx.digest
#
# Find available versions from: https://fontawesome.com/download

set -e

FA_VERSION="7.1.0"
FA_DIR="fontawesome-free-${FA_VERSION}-web"
ZIP_FILE="${FA_DIR}.zip"
FA_URL="https://use.fontawesome.com/releases/v${FA_VERSION}/${ZIP_FILE}"
ZIP_DIR=$(mktemp -d)

cleanup() {
    rm -rf "$ZIP_DIR"
}
trap cleanup EXIT

if [ ! -f "mix.exs" ]; then
    echo "This script must be run from the project root directory where mix.exs is located."
    exit 1
fi

if [ ! -f "/tmp/${ZIP_FILE}" ]; then
    echo "Downloading Font Awesome ${FA_VERSION}..."
    curl -L -o "/tmp/${ZIP_FILE}" "${FA_URL}"
fi

echo "Extracting Font Awesome ${FA_VERSION} to ${ZIP_DIR}..."
unzip -q "/tmp/${ZIP_FILE}" -d "${ZIP_DIR}"

echo "Removing old Font Awesome files..."
rm -rf priv/static/fontawesome
mkdir -p priv/static/fontawesome/css

echo "Copying Font Awesome files..."
cp "${ZIP_DIR}/${FA_DIR}/LICENSE.txt" "priv/static/fontawesome/LICENSE.txt"
cp "${ZIP_DIR}/${FA_DIR}/css/all.min.css" "priv/static/fontawesome/css/all.min.css"
cp -r "${ZIP_DIR}/${FA_DIR}/webfonts" "priv/static/fontawesome/webfonts"

echo "Font Awesome ${FA_VERSION} update complete."
echo "Remember to run 'mix phx.digest' to update the asset digests."
