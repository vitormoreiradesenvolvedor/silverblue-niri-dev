# zsh nao le /etc/profile.d em shells interativos nao-login.
# shellcheck disable=SC1091
[ -r /etc/profile.d/custom-dev-env.sh ] && . /etc/profile.d/custom-dev-env.sh

HISTFILE="${HOME}/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000
setopt share_history hist_ignore_dups

autoload -Uz compinit && compinit -u
autoload -Uz colors && colors
PROMPT='%F{cyan}%n@%m%f %F{yellow}%~%f %# '
