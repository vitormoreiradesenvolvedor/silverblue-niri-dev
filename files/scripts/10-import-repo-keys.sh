#!/usr/bin/bash
# Importa as chaves GPG dos repositorios de terceiros copiados em
# /etc/yum.repos.d/ pelo modulo `files`. Sem isso o dnf tentaria pedir
# confirmacao interativa durante o build.
set -euo pipefail

KEYS=(
  "https://download.docker.com/linux/fedora/gpg"
  "https://dl.google.com/linux/linux_signing_key.pub"
  "https://brave-browser-rpm-release.s3.brave.com/brave-core.asc"
  "https://repository.mullvad.net/rpm/mullvad-keyring.asc"
)

for key in "${KEYS[@]}"; do
  echo "::group:: Importando chave ${key}"
  curl -fsSL --retry 5 --retry-delay 3 -o /tmp/repo-key.asc "${key}"
  rpm --import /tmp/repo-key.asc
  rm -f /tmp/repo-key.asc
  echo "::endgroup::"
done
