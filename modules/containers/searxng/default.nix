{
  config,
  vars,
  funcs,
  lib,
  ...
}: let
  localVars = vars.containers.containers;

  searxngImage = "ghcr.io/searxng/searxng:2025.12.12-920b40253";
  valkeyImage = "ghcr.io/valkey-io/valkey:9.0.1";

  searxngConfigDir = funcs.relativeToAbsoluteConfigPath ./config;
  searxngDataDir = "${vars.containers.dataDir}/searxng/data";
  valkeyDataDir = "${vars.containers.dataDir}/searxng/valkey-data";
in {
  options.opts.containers.searxng = {
    enable = lib.mkEnableOption "SearXNG";
    autoStart = lib.mkEnableOption "SearXNG auto-start";
  };

  config = lib.mkIf config.opts.containers.searxng.enable {
    systemd.tmpfiles.rules = [
      "d ${searxngConfigDir} 2770 ${vars.username} ${localVars.searxng.mainGroup} - -"
      "d ${vars.containers.dataDir}/searxng 2770 ${vars.username} ${localVars.searxng.mainGroup} - -"
      "d ${searxngDataDir} 2770 ${vars.username} ${localVars.searxng.mainGroup} - -"
      "d ${valkeyDataDir} 2770 ${vars.username} ${localVars.searxng-valkey.mainGroup} - -"

      "Z ${searxngConfigDir} 2770 ${vars.username} ${localVars.searxng.mainGroup} - -"
      "Z ${vars.containers.dataDir}/searxng 2770 ${vars.username} ${localVars.searxng.mainGroup} - -"
      "Z ${valkeyDataDir} 2770 ${vars.username} ${localVars.searxng-valkey.mainGroup} - -"
    ];
    secrets.searxng = {
      sopsFile = ./secrets.env;
      format = "dotenv";
      # Entire file.
      key = "";
      # Only the user can read and nothing else.
      mode = "0400";
      owner = vars.username;
    };
    hm = {
      # https://seiarotg.github.io/quadlet-nix/home-manager-options.html
      virtualisation.quadlet = {
        containers = {
          searxng = funcs.containers.mkConfig "searxng" localVars.searxng {
            autoStart = config.opts.containers.searxng.autoStart;
            unitConfig = {
              Requires = "searxng-valkey.container";
            };
            containerConfig = {
              image = searxngImage;
              # publishPorts = ["8080:8080"];
              environments = {
                FORCE_OWNERSHIP = "false";
              };
              environmentFiles = [config.secrets.searxng.path];
              volumes = [
                "${searxngConfigDir}:/etc/searxng"
                "${searxngDataDir}:/var/cache/searxng"
              ];
              networks = ["searxng"];
            };
          };
          searxng-valkey = funcs.containers.mkConfig "valkey" localVars.searxng-valkey {
            containerConfig = {
              image = valkeyImage;
              exec = "valkey-server --save 30 1";
              volumes = ["${valkeyDataDir}:/data"];
              networkAliases = ["valkey"];
              networks = ["searxng"];
            };
          };
        };
        networks.searxng = {};
      };
    };
  };
}
