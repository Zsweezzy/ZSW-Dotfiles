source /usr/share/cachyos-zsh-config/cachyos-config.zsh
# >>> Photon CLI >>>
case ":$PATH:" in
  *:'/home/maxii/.photon/bin':*) ;;
  *) export PATH="$PATH":'/home/maxii/.photon/bin' ;;
esac
# <<< Photon CLI <<<
