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
end

# ── Aliases ─────────────────────────────────────────────────────────────
alias e exit

# bun
set --export BUN_INSTALL "$HOME/.bun"
set --export PATH $BUN_INSTALL/bin $PATH

# GitHub MCP server auth for opencode's remote MCP entry.
# Derived from the authenticated gh CLI so the token is never hardcoded.
set -gx GITHUB_PERSONAL_ACCESS_TOKEN (gh auth token 2>/dev/null)
# Nix removed 2026-10-20: nix-daemon.sh + hm-session-vars.sh sourced here before.



# Starship prompt
if command -q starship
    starship init fish | source
end
