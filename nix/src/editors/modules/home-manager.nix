{ ... }:
{
  # avoid neovim due to store conflict; don't clobber existing micro config
  programs.helix.enable = true;
  programs.micro.enable = false;
}
