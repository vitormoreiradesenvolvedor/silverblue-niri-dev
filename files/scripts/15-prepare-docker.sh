#!/usr/bin/bash
# 1. O repositorio oficial do Docker CE costuma ficar alguns meses atras do
#    Fedora rawhide/estavel mais novo. Resolve o maior $releasever que exista
#    de fato e fixa no .repo, senao o build quebra com 404.
# 2. Remove pacotes da imagem base que colidem com docker-ce
#    (podman-docker fornece /usr/bin/docker, moby-engine/runc colidem com
#    containerd.io).
set -euo pipefail

REPO_FILE="/etc/yum.repos.d/docker-ce.repo"
CURRENT="$(rpm -E %fedora)"

resolved=""
for (( ver=CURRENT; ver>=39; ver-- )); do
  url="https://download.docker.com/linux/fedora/${ver}/x86_64/stable/Packages/"
  if curl -fsSL --head --retry 3 "${url}" >/dev/null 2>&1; then
    resolved="${ver}"
    break
  fi
done

if [[ -z "${resolved}" ]]; then
  echo "ERRO: nenhum releasever do repo Docker CE respondeu (39..${CURRENT})" >&2
  exit 1
fi

echo "Repo Docker CE: usando releasever=${resolved} (sistema=${CURRENT})"
sed -i "s|/linux/fedora/\$releasever/|/linux/fedora/${resolved}/|" "${REPO_FILE}"

for pkg in podman-docker moby-engine docker docker-cli runc containerd; do
  if rpm -q "${pkg}" >/dev/null 2>&1; then
    echo "Removendo pacote conflitante: ${pkg}"
    dnf -y remove --noautoremove "${pkg}"
  fi
done
