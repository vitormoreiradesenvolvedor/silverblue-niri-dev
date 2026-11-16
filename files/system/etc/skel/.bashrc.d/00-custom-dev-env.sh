# O .bashrc padrao do Fedora faz source de ~/.bashrc.d/*.sh em shells
# interativos nao-login (terminal do niri, por exemplo). Reaproveita o
# mesmo arquivo global para nao duplicar configuracao.
# shellcheck disable=SC1091
[ -r /etc/profile.d/custom-dev-env.sh ] && . /etc/profile.d/custom-dev-env.sh
