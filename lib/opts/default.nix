# For options that are reused in multiple places.
{
  config,
  lib,
  pkgs,
  funcs,
  ...
}:
with lib;
{
  # Check the NixOS GitHub manual for info on option types.
  # https://github.com/NixOS/nixpkgs/blob/master/nixos/doc/manual/development/option-types.section.md
  options.opts = {
    autostartScripts = mkOption {
      default = { };
      type = with types; attrsOf str;
    };
    autostartSymlinks = mkOption {
      default = { };
      type = with types; attrsOf path;
    };
  };

  config = {
    hm.home.file =
      (listToAttrs (
        mapAttrsToList (name: script: {
          name = ".config/autostart/${name}.script.desktop";
          value.text = ''
            [Desktop Entry]
            Exec=${pkgs.writeShellScript name script}
            Name=${name}
            Type=Application
            X-KDE-AutostartScript=true
          '';
        }) config.opts.autostartScripts
      ))
      // (listToAttrs (
        mapAttrsToList (name: path: {
          name = ".config/autostart/${name}.symlink.desktop";
          value.source = funcs.mkOutOfStoreSymlink path;
        }) config.opts.autostartSymlinks
      ));
  };
}
