#!/usr/bin/env bash
#
# Gera o ISO instalavel da imagem silverblue-niri-dev usando bootc-image-builder.
#
# Precisa de root real: o builder cria loop devices e monta sistemas de arquivos,
# o que podman rootless nao consegue fazer.
#
# Uso:
#   ./gerar-iso.sh                    # pergunta usuario e senha
#   USUARIO=vmoreira SENHA=xxx ./gerar-iso.sh
#
set -euo pipefail

IMAGEM="${IMAGEM:-ghcr.io/vitormoreiradesenvolvedor/silverblue-niri-dev:latest}"
BUILDER="${BUILDER:-quay.io/centos-bootc/bootc-image-builder:latest}"
TIPO="${TIPO:-anaconda-iso}"   # anaconda-iso = instalador em pendrive; qcow2 = VM
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SAIDA="$RAIZ/output"

USUARIO="${USUARIO:-}"
SENHA="${SENHA:-}"

if [[ -z "$USUARIO" ]]; then
    read -r -p "Usuario do novo sistema [vmoreira]: " USUARIO
    USUARIO="${USUARIO:-vmoreira}"
fi

if [[ -z "$SENHA" ]]; then
    read -r -s -p "Senha inicial de $USUARIO: " SENHA; echo
    read -r -s -p "Confirme a senha: " SENHA2; echo
    if [[ "$SENHA" != "$SENHA2" ]]; then
        echo "As senhas nao coincidem." >&2
        exit 1
    fi
fi

# O config.toml carrega o hash da senha, entao fica fora do repositorio
# (que e publico) e e apagado ao final, inclusive se o build falhar.
CONFIG="$(mktemp --tmpdir=/var/tmp config-bib-XXXXXX.toml)"
chmod 600 "$CONFIG"
trap 'rm -f "$CONFIG"' EXIT

HASH="$(openssl passwd -6 "$SENHA")"
cat > "$CONFIG" <<EOF
[[customizations.user]]
name = "$USUARIO"
password = "$HASH"
# wheel  = sudo
# docker = usar docker sem sudo
# dialout = acesso a portas seriais/USB
groups = ["wheel", "docker", "dialout"]
EOF
unset SENHA SENHA2 HASH

mkdir -p "$SAIDA"

echo
echo "Imagem : $IMAGEM"
echo "Tipo   : $TIPO"
echo "Saida  : $SAIDA"
echo "Baixa ~5 GB e leva de 10 a 25 minutos. Sudo vai pedir sua senha."
echo

# --privileged                      : loop devices e mount
# --security-opt label=type:unconfined_t : SELinux no host atomico
# -v /var/lib/containers/storage    : reaproveita a storage do podman root
sudo podman run \
    --rm -it \
    --privileged \
    --pull=newer \
    --security-opt label=type:unconfined_t \
    -v "$CONFIG":/config.toml:ro \
    -v "$SAIDA":/output \
    -v /var/lib/containers/storage:/var/lib/containers/storage \
    "$BUILDER" \
    --type "$TIPO" \
    --config /config.toml \
    "$IMAGEM"

echo
echo "Pronto. Arquivos gerados:"
sudo find "$SAIDA" -type f \( -name '*.iso' -o -name '*.qcow2' \) -printf '%p  (%s bytes)\n'
echo
echo "O instalador cria o usuario '$USUARIO' com a senha que voce digitou."
echo "Troque a senha depois do primeiro login: passwd"
echo
echo "Gravar no pendrive (CONFIRA o dispositivo com 'lsblk' antes, apagar o disco errado e irreversivel):"
echo "  sudo dd if=$SAIDA/bootiso/install.iso of=/dev/sdX bs=4M status=progress oflag=direct conv=fsync"
