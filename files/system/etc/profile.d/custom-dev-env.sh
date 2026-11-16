# shellcheck shell=sh
# Ambiente de desenvolvimento global da imagem silverblue-niri-dev.
# Carregado por shells de login (bash, zsh via /etc/profile) e tambem por
# shells interativos bash atraves de /etc/skel/.bashrc.d/00-custom-dev-env.sh.

# --- Homebrew -----------------------------------------------------------
if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    # Sem auto-update a cada comando: a imagem ja e atualizada semanalmente.
    export HOMEBREW_NO_AUTO_UPDATE=1
    export HOMEBREW_NO_ENV_HINTS=1
fi

# --- Rust / cargo -------------------------------------------------------
export CARGO_HOME="${CARGO_HOME:-$HOME/.cargo}"
export RUSTUP_HOME="${RUSTUP_HOME:-$HOME/.rustup}"
case ":${PATH}:" in
    *":${CARGO_HOME}/bin:"*) ;;
    *) PATH="${CARGO_HOME}/bin:${PATH}" ;;
esac

# --- snap ---------------------------------------------------------------
case ":${PATH}:" in
    *":/snap/bin:"*) ;;
    *) PATH="${PATH}:/snap/bin" ;;
esac
export XDG_DATA_DIRS="${XDG_DATA_DIRS:-/usr/local/share:/usr/share}:/var/lib/snapd/desktop"

# --- npm global do usuario (pacotes instalados sem sudo) ----------------
export npm_config_prefix="${npm_config_prefix:-$HOME/.local}"
case ":${PATH}:" in
    *":${HOME}/.local/bin:"*) ;;
    *) PATH="${HOME}/.local/bin:${PATH}" ;;
esac

export PATH

# --- SDKMAN! ------------------------------------------------------------
# Precisa ser a ULTIMA coisa: o init do sdkman reescreve o PATH.
export SDKMAN_DIR="${SDKMAN_DIR:-$HOME/.sdkman}"
if [ -s "${SDKMAN_DIR}/bin/sdkman-init.sh" ]; then
    # shellcheck disable=SC1091
    . "${SDKMAN_DIR}/bin/sdkman-init.sh"
fi
