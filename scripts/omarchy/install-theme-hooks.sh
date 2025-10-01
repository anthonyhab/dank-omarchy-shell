#!/usr/bin/env bash
set -euo pipefail

HOOK_TARGET_DIR="${HOME}/.config/omarchy/theme-hooks"
TEMPLATE_TARGET_DIR="${HOME}/.config/omarchy/theme-generator/templates"

mkdir -p "${HOOK_TARGET_DIR}" "${TEMPLATE_TARGET_DIR}"

install -m 755 "$(dirname "$0")/dank-shell.py" "${HOOK_TARGET_DIR}/dank-shell.py"
install -m 644 "$(dirname "$0")/templates/qtct-colors.conf.j2" "${TEMPLATE_TARGET_DIR}/qtct-colors.conf.j2"
install -m 644 "$(dirname "$0")/templates/firefox-userchrome.css.j2" "${TEMPLATE_TARGET_DIR}/firefox-userchrome.css.j2"

echo "✓ Installed Omarchy theme hook and Qt template."
