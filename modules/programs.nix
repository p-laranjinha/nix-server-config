{pkgs, ...}: {
  nixpkgs.config = {
    # Allow unfree packages
    allowUnfree = true;
    # Workaround for https://github.com/nix-community/home-manager/issues/2942
    allowUnfreePredicate = _: true;
  };

  environment.systemPackages = with pkgs; [
    unrar
    p7zip
  ];
}
