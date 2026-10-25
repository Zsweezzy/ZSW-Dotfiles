{ ... }:
{
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Maxii";
        email = "zsweezzy@users.noreply.github.com";
      };
      init.defaultBranch = "main";
      pull.rebase = false;
      push.autoSetupRemote = true;
      credential = {
        "https://github.com" = { helper = "!/nix/store/x6kcq7g4cwysbwjiyz152rbl6fv7l55w-gh-2.102.0/bin/.gh-wrapped auth git-credential"; };
        "https://gist.github.com" = { helper = "!/nix/store/x6kcq7g4cwysbwjiyz152rbl6fv7l55w-gh-2.102.0/bin/.gh-wrapped auth git-credential"; };
      };
    };
  };
}
