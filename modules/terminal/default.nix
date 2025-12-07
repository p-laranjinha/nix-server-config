{
  pkgs,
  vars,
  funcs,
  ...
}: {
  environment.shellAliases = {
    lg = "lazygit";

    # Undoes a commit but keeps the changes.
    gitr = "git reset --soft HEAD~1";

    # Runs a script that rebuild switches this config.
    nixs = toString (funcs.mkMutableConfigSymlink ./nixs.sh);
    # Runs a script that rebuild switches and commits this config.
    nixsf = toString (funcs.mkMutableConfigSymlink ./nixsf.sh);
    nixb = "sudo nixos-rebuild build --flake ${vars.configDirectory}";
    nixl = "nixos-rebuild list-generations";
    nixu = "nix flake update --flake ${vars.configDirectory}";

    # "nix query"
    # Runs nix repl initialized with values from this flake for easier testing and debugging.
    nixq = ''nix repl --file ${pkgs.writeText "replinit.nix" ''
        let
          self = builtins.getFlake "config";
        in rec {
          inherit self;
          inherit (self) inputs lib;
          inherit (self.nixosConfigurations) ${vars.hostname};
          inherit (self.nixosConfigurations.${vars.hostname}._module.specialArgs) vars;
          inherit (self.nixosConfigurations.${vars.hostname}._module.args) funcs;
        }
      ''}'';
  };
  programs.bash = {
    enable = true;
  };
  programs.git = {
    enable = true;
    config = {
      init.defaultBranch = "master";
      user.name = "p-laranjinha";
      user.email = "plcasimiro2000@gmail.com";

      core.pager = "delta";
      interactive.diffFilter = "delta --color-only";
      delta.navigate = "true"; # use n and N to move between diff sections
      delta.dark = "true";
      delta.line-numbers = "true";
      delta.hyperlinks = "true";
      merge.conflictStyle = "zdiff3";
    };
    # Git extension for versioning large files (Git Large File Storage).
    lfs.enable = true;
  };
  # Tool to locate the nixpkgs package providing a certain file. Used by comma.
  programs.nix-index.enable = true;

  hm = {
    programs.gh.enable = true;

    # Throws an error when not set with home manager.
    programs.zoxide.enable = true;
    # Required for zoxide to set the 'z' and 'zi' commands when set with home manager.
    programs.bash.enable = true;
  };

  environment.systemPackages = with pkgs; [
    # Tool to remove large files from git history. Call with "bfg".
    bfg-repo-cleaner

    # TUI for git.
    lazygit

    # App to give quick examples of how to use most commands.
    tldr

    # CLI tool to run programs without installing them on Nix. Functionally an easier to use nix-shell. Requires nix-index.
    comma

    # Nix formatter.
    alejandra
    # Nix language server.
    nil
    # Nix package version diff tool.
    nvd

    # find replacement, used to update fetchgit references together with update-nix-fetchgit in nixr.
    fd
    update-nix-fetchgit

    gum

    # Tool to see file changes in real time.
    fswatch

    # Syntax highlighting pager.
    delta

    bat

    # # You can also create simple shell scripts directly inside your
    # # configuration. For example, this adds a command 'my-hello' to your
    # # environment:
    # (pkgs.writeShellScriptBin "my-hello" ''
    #   echo "Hello, ${config.home.username}!"
    # '')
  ];
}
