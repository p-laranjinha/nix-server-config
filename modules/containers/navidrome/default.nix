{
  vars,
  funcs,
  config,
  lib,
  ...
}: let
  localVars = vars.containers.containers.navidrome;

  navidromeImage = "ghcr.io/navidrome/navidrome:0.59.0";

  navidromeDataDir = "${vars.containers.dataDir}/navidrome/data";
  musicDir = "${vars.containers.publicDir}/music";
in {
  options.opts.containers.navidrome = {
    enable = lib.mkEnableOption "Navidrome";
    autoStart = lib.mkEnableOption "Navidrome auto-start";
  };

  config = lib.mkIf config.opts.containers.navidrome.enable {
    systemd.tmpfiles.rules = [
      "d ${vars.containers.dataDir}/navidrome 2770 ${vars.username} ${localVars.mainGroup} - -"
      "d ${navidromeDataDir} 2770 ${vars.username} ${localVars.mainGroup} - -"
      "d ${musicDir} 2770 ${vars.username} public - -"
      "d ${musicDir}/default 2770 ${vars.username} public - -"
    ];
    hm = {
      virtualisation.quadlet = {
        containers = {
          navidrome = funcs.containers.mkConfig "1000" localVars {
            autoStart = config.opts.containers.navidrome.autoStart;
            containerConfig = {
              image = navidromeImage;
              environments = {
                ND_LOGLEVEL = "debug";
                # Use a default subfolder for multi-library support.
                ND_MUSICFOLDER = "/music/default";
                ND_BASEURL = "https://music.orangpebble.net";
                ND_EXTAUTH_TRUSTEDSOURCES = "10.0.0.0/8";
                ND_ENABLEUSEREDITING = "false";
              };
              volumes = [
                "${navidromeDataDir}:/data"
                "${musicDir}:/music:ro"
              ];
            };
          };
        };
      };
    };
  };
}
