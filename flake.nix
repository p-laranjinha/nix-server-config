{
  description = "flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    # nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";

    home-manager = {
      url = "github:nix-community/home-manager";
      # url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    quadlet-nix.url = "github:SEIAROTg/quadlet-nix";

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
    ...
  } @ inputs: let
    # Common information about the system that may be used in multiple locations.
    # Using camelCase because that is the standard for options. kebab-case is for packages and files.
    this = {
      hostname = "server";
      username = "pebble";
      fullname = "Orange Pebble";
      homeDirectory = "/home/pebble";
      configDirectory = "${this.homeDirectory}/nix-server-config";
      hostPlatform = "x86_64-linux";
      # Research properly before changing this.
      stateVersion = "25.05";
    };

    lib = (nixpkgs.lib.extend (_: _: home-manager.lib)).extend (import ./lib);
  in {
    inherit lib;
    nixosConfigurations.${this.hostname} = nixpkgs.lib.nixosSystem {
      inherit lib;
      modules =
        (lib.attrValues (lib.modulesIn ./modules))
        ++ [];
      specialArgs = {
        inherit inputs;
        inherit this;
      };
    };
  };
}
