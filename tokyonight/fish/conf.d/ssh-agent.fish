# Point ssh at the systemd user agent (ssh-agent.socket), starting it on demand.
if not set -q SSH_AUTH_SOCK
    set -gx SSH_AUTH_SOCK $XDG_RUNTIME_DIR/ssh-agent.socket
end
