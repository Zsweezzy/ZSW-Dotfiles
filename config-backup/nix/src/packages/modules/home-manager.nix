{ pkgs, ... }:
let
  # nix glvnd/vulkan only search /run/opengl-driver (NixOS-only path), so on
  # CachyOS they fall through to the system mesa json and Firefox silently
  # renders in software. Point EGL/Vulkan at nix mesa instead; this is set
  # per-app rather than session-wide so Steam/games keep the system stack.
  mesa = pkgs.mesa;
  firefox-nix = pkgs.symlinkJoin {
    name = "firefox";
    paths = [ pkgs.firefox ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/firefox \
        --set __EGL_VENDOR_LIBRARY_FILENAMES "${mesa}/share/glvnd/egl_vendor.d/50_mesa.json" \
        --set VK_DRIVER_FILES "${mesa}/share/vulkan/icd.d/radeon_icd.x86_64.json" \
        --set LIBVA_DRIVERS_PATH "${mesa}/lib/dri"
    '';
    # shortcut: mesa's gbm loader still logs "failed to open dri_gbm.so"
    # (it looks in /run/opengl-driver/lib/gbm); Wayland EGL compositing works,
    # add GBM_BACKENDS_PATH if dmabuf/video decode ever misbehaves.
  };
in
{
  home.packages = with pkgs; [
    firefox-nix
    bat
    eza
    fd
    fzf
    ripgrep
    jq
    yq-go
    zoxide
    atuin
    starship
    direnv
    gh
    git
    lazygit
    gitui
    bottom
    btop
    dust
    procs
    htop
    fastfetch
    hyfetch
    tree
    wget
    curl
    unzip
    p7zip
    zip
    tmux
    zellij
    zsh
    fish
    nushell
    bash-completion
    neovim
    helix
    micro
    nodejs
    bun
    python3
    uv
    pipx
    rustup
    go
    clang
    cmake
    pkg-config
    ninja
    meson
    just
    gnumake
    shellcheck
    shfmt
    nixfmt
    alejandra
    taplo
    stylua
    biome
    prettier
    sd
    tokei
    hyperfine
    tealdeer
    glow
    cht-sh
    doggo
    xh
    httpie
    delta
    difftastic
    rsync
    openssl
    age
    sops
    gnupg
    pinentry-curses
    yazi
    duf
    cbonsai
    cmatrix
    ncdu
    dua
    glances
    hwinfo
    strace
    pv
    yt-dlp
    ffmpeg-full
    ffmpegthumbnailer
    imagemagick
    poppler-utils
    tesseract
    lshw
    dmidecode
    file
    which
    wdiff
    colordiff
    icdiff
    grim
    slurp
    cliphist
    wl-clipboard
    playerctl
    brightnessctl
    killall
    lsof
    pciutils
    usbutils
  ];

  # shadow /usr/share/applications/firefox.desktop so menu/rofi launches also
  # use the nix build (its Exec is bare "firefox", resolved via PATH).
  xdg.dataFile."applications/firefox.desktop".source =
    "${firefox-nix}/share/applications/firefox.desktop";
}
