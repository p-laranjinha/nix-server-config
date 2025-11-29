# For lib functions that depend on modules like nixos and home-manager.
# There might be a way to create these functions with mkOption instead of
#  abusing config.lib.meta, but I don't think it's worth the trouble.
# These functions are accessed by config.lib.meta.XXX
# For more "pure" functions check ../lib
{
  this,
  config,
  lib,
  pkgs,
  ...
}:
with lib; {
  lib.meta = {
    mkOutOfStoreSymlink = path: config.hm.lib.file.mkOutOfStoreSymlink path;

    relativeToAbsoluteConfigPath = path: (this.configDirectory + removePrefix (toString ./..) (toString path));

    # Creates symlinks to these config files that can be changed without rebuilding.
    mkMutableConfigSymlink = path:
      config.lib.meta.mkOutOfStoreSymlink (config.lib.meta.relativeToAbsoluteConfigPath path);

    # Use like: hm.home.file = mkAutostartScript "name" ''script''
    mkAutostartScript = name: script: {
      ".config/autostart/${name}.desktop".text = ''
        [Desktop Entry]
        Exec=${pkgs.writeShellScript name script}
        Name=${name}
        Type=Application
        X-KDE-AutostartScript=true
      '';
    };
    # Use like: hm.home.file = mkAutostartSymlink "name" path
    mkAutostartSymlink = name: path: {
      ".config/autostart/${name}.desktop".source = config.lib.meta.mkOutOfStoreSymlink path;
    };
  };
}
