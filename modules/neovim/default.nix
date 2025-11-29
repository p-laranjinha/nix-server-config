{
  pkgs,
  config,
  ...
}: {
  hm = {
    home.packages = with pkgs; [
      # Dependencies
      gcc
      unzip # Used to install LSPs with Mason.
      ripgrep
      fzf
      cargo # Used to install the nil nix LSP.
      wl-clipboard # Clipboard provider for Wayland.
      xclip # Clipboard provider for X11/RDP
      nodejs_24 # For the bash LSP.
    ];
    home.file.".config/nvim".source = config.lib.meta.mkMutableConfigSymlink ./config;
    home.shellAliases = {
      vi = "nvim";
      vim = "nvim";
    };
    programs.neovim = {
      enable = true;
      defaultEditor = true;
    };
  };
}
