{
  pkgs,
  vars,
  funcs,
  ...
}: {
  hm = {
    home.shellAliases = {
      lg = "lazygit";

      # Undoes a commit but keeps the changes.
      gitr = "git reset --soft HEAD~1";

      # "nix rebuild"
      # Runs a script that rebuilds this flake.
      nixr = toString (funcs.mkMutableConfigSymlink ./nixr.sh);
      nixs = toString (funcs.mkMutableConfigSymlink ./nixs.sh);
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
      settings = {
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
    programs.gh = {
      enable = true;
    };

    # Tool to locate the nixpkgs package providing a certain file. Used by comma.
    programs.nix-index = {
      enable = true;
      # Makes the command-not-found error return the nixpkgs package that contains it.
      enableBashIntegration = true;
    };

    programs.zoxide.enable = true;

    home.packages = with pkgs; [
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
  };
}
