#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '
. "$HOME/.cargo/env"
export PATH="$HOME/.local/bin:$PATH"
# >>> Photon CLI >>>
case ":$PATH:" in
  *:'/home/maxii/.photon/bin':*) ;;
  *) export PATH="$PATH":'/home/maxii/.photon/bin' ;;
esac
# <<< Photon CLI <<<
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
. /home/maxii/.nix-profile/etc/profile.d/hm-session-vars.sh
