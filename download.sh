#!/usr/bin/env bash
#shellcheck disable=SC2034
#SC2034: foo appears unused. Verify it or export it.

# Usage:
# # curl https://raw.githubusercontent.com/angryguy-win/arch_install/main/install.sh | bash
# # or
# # curl https://raw.githubusercontent.com/angryguy-win/arch_install/main/download.sh | bash
# # vim arch_config.toml
# # ./install.sh
set -eu

GITHUB_USER="angryguy-win"
BRANCH="main"
HASH=""
ARTIFACT="arch_install-${BRANCH}"

while getopts "b:h:u:" arg; do
  case ${arg} in
    b)
      BRANCH="${OPTARG}"
      ARTIFACT="arch_install-${BRANCH}"
      ;;
    h)
      HASH="${OPTARG}"
      ARTIFACT="arch_install-${HASH}"
      ;;
    u)
      GITHUB_USER=${OPTARG}
      ;;
    ?)
      echo "Invalid option: -${OPTARG}."
      exit 1
      ;;
  esac
done

set -o xtrace
if [ -n "$HASH" ]; then
  curl -sL -o "${ARTIFACT}.zip" "https://github.com/${GITHUB_USER}/arch_install/archive/${HASH}.zip"
  bsdtar -x -f "${ARTIFACT}.zip"
  cp -R "${ARTIFACT}"/*.sh "${ARTIFACT}"/*.conf "${ARTIFACT}"/files/ "${ARTIFACT}"/configs/ ./
else
  curl -sL -o "${ARTIFACT}.zip" "https://github.com/${GITHUB_USER}/arch_install/archive/refs/heads/${BRANCH}.zip"
  bsdtar -x -f "${ARTIFACT}.zip"
  cp -R "${ARTIFACT}"/*.sh "${ARTIFACT}"/*.conf "${ARTIFACT}"/scripts/ "${ARTIFACT}"/config/ "${ARTIFACT}"/lib/ ./
  cp -R "${ARTIFACT}"/*.toml "${ARTIFACT}/help" "${ARTIFACT}/backups" ./
fi
chmod +x ./*.sh
