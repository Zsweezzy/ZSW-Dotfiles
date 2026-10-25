#
# ~/.bash_profile
#

[[ -f ~/.bashrc ]] && . ~/.bashrc
. "$HOME/.cargo/env"
# >>> Photon CLI >>>
case ":$PATH:" in
  *:'/home/maxii/.photon/bin':*) ;;
  *) export PATH="$PATH":'/home/maxii/.photon/bin' ;;
esac
# <<< Photon CLI <<<
