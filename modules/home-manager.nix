{
  inputs,
  lib,
  this,
  ...
}: {
  imports = [
    inputs.home-manager.nixosModules.default
    (lib.mkAliasOptionModule ["hm"] ["home-manager" "users" this.username])
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    verbose = true;
    backupFileExtension = "backup";
    overwriteBackup = false;
    extraSpecialArgs = {inherit inputs;};
    # For modules shared by all users;
    sharedModules = [];
  };

  hm = {
    home = {
      username = this.username;
      homeDirectory = this.homeDirectory;
      stateVersion = this.stateVersion;
    };

    # Nicely reload system units when changing configs.
    systemd.user.startServices = "sd-switch";

    # Let Home Manager install and manage itself.
    programs.home-manager.enable = true;
  };
}
