source /usr/share/cachyos-fish-config/cachyos-config.fish

# Use the locally patched Fetch instead of CachyOS's fastfetch greeting
# Its --- group markers render as --------.
function fish_greeting
    ~/.local/bin/fetch
end

fish_add_path /home/maxii/.spicetify

# ── Prompt engine (starship | omp) ──────────────────────────────────────
# Switch with: prompt_engine starship   (or)   prompt_engine omp
if not set -q PROMPT_ENGINE
    set -g PROMPT_ENGINE starship
end

function prompt_engine
    if not set -q argv[1]
        echo "usage: prompt_engine starship|omp"
        return 1
    end
    set -g PROMPT_ENGINE $argv[1]
    exec fish
end

switch $PROMPT_ENGINE
    case starship
        starship init fish | source
    case omp
        oh-my-posh init fish --config ~/.config/oh-my-posh/tokyonight-moon.omp.json | source
end

# ── Aliases ─────────────────────────────────────────────────────────────
alias e exit

# Strata local LLM server (kitty: `strata start` / `strata stop`)
function strata
    switch "$argv[1]"
        case start
            nohup ~/Strata/run-coder-iq1_m.sh > ~/Strata/strata-server.out 2>&1 &
            echo "Strata running at http://127.0.0.1:8080"
        case stop
            pkill -f 'serve/server.py'
            pkill -f 'engine/strata'
            echo "strata stopped"
        case '*'
            echo "usage: strata start|stop"
    end
end



# bun
set --export BUN_INSTALL "$HOME/.bun"
set --export PATH $BUN_INSTALL/bin $PATH

# GitHub MCP server auth for opencode's remote MCP entry.
# Derived from the authenticated gh CLI so the token is never hardcoded.
set -gx GITHUB_PERSONAL_ACCESS_TOKEN (gh auth token 2>/dev/null)
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
if test -f /home/maxii/.nix-profile/etc/profile.d/hm-session-vars.sh
    fenv source /home/maxii/.nix-profile/etc/profile.d/hm-session-vars.sh 2>/dev/null
end
