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
# As imagens Universal Blue nao trazem /usr/lib/bootc/install/*.toml, entao o
# builder nao sabe qual filesystem usar na raiz e aborta. ext4 e o caminho mais
# testado do bootc-image-builder; xfs e btrfs tambem valem (ROOTFS=btrfs).
ROOTFS="${ROOTFS:-ext4}"
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
echo "Raiz   : $ROOTFS"
echo "Saida  : $SAIDA"
echo "Baixa ~5 GB e leva de 10 a 25 minutos. Sudo vai pedir sua senha."
echo

# Sem tty (rodando dentro de um agente, de um cron, de um pipe) o sudo nao
# consegue perguntar nada e o podman nao pode alocar terminal.
SUDO=(sudo)
PODMAN_TTY=(-it)
if [[ ! -t 0 ]]; then
    PODMAN_TTY=()
    if ! sudo -n true 2>/dev/null; then
        # -A faz o sudo pedir a senha por um helper grafico, numa janela.
        ASKPASS="${SUDO_ASKPASS:-}"
        if [[ -z "$ASKPASS" ]]; then
            for cand in /usr/bin/ksshaskpass /usr/libexec/openssh/ssh-askpass \
                        /usr/libexec/seahorse/ssh-askpass; do
                [[ -x "$cand" ]] && { ASKPASS="$cand"; break; }
            done
        fi
        if [[ -z "$ASKPASS" ]]; then
            echo "Sem tty e sem helper de senha grafico. Rode este script" >&2
            echo "direto no terminal, ou exporte SUDO_ASKPASS." >&2
            exit 1
        fi
        export SUDO_ASKPASS="$ASKPASS"
        SUDO=(sudo -A)
        echo "Digite a senha do sudo na janela que vai abrir."
    fi
fi

# Versoes recentes do bootc-image-builder nao puxam mais a imagem: ela tem de
# estar na storage do podman ROOT antes, senao morre com "image not known".
echo "Baixando $IMAGEM para a storage do root..."
"${SUDO[@]}" podman pull "$IMAGEM"

# --privileged                      : loop devices e mount
# --security-opt label=type:unconfined_t : SELinux no host atomico
# -v /var/lib/containers/storage    : reaproveita a storage do podman root
"${SUDO[@]}" podman run \
    --rm "${PODMAN_TTY[@]}" \
    --privileged \
    --pull=newer \
    --security-opt label=type:unconfined_t \
    -v "$CONFIG":/config.toml:ro \
    -v "$SAIDA":/output \
    -v /var/lib/containers/storage:/var/lib/containers/storage \
    "$BUILDER" \
    --type "$TIPO" \
    --rootfs "$ROOTFS" \
    --config /config.toml \
    "$IMAGEM"

echo
echo "Pronto. Arquivos gerados:"
"${SUDO[@]}" find "$SAIDA" -type f \( -name '*.iso' -o -name '*.qcow2' \) -printf '%p  (%s bytes)\n'
echo
echo "O instalador cria o usuario '$USUARIO' com a senha que voce digitou."
echo "Troque a senha depois do primeiro login: passwd"
echo
echo "Gravar no pendrive (CONFIRA o dispositivo com 'lsblk' antes, apagar o disco errado e irreversivel):"
echo "  sudo dd if=$SAIDA/bootiso/install.iso of=/dev/sdX bs=4M status=progress oflag=direct conv=fsync"
