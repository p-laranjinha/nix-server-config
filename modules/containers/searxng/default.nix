{
  config,
  vars,
  funcs,
  lib,
  ...
}: let
  localVars = vars.containers.containers;
  searxngConfigDir = funcs.relativeToAbsoluteConfigPath ./config;
  searxngDataDir = "${vars.containers.dataDir}/searxng/data";
  valkeyDataDir = "${vars.containers.dataDir}/searxng/valkey-data";
in {
  options.opts.containers.searxng.enable = lib.mkOption {
    default = config.opts.containers.enable;
    type = lib.types.bool;
  };

  config = lib.mkIf config.opts.containers.searxng.enable {
    systemd.tmpfiles.rules = [
      "d ${searxngConfigDir} 2770 ${vars.username} ${localVars.searxng.mainGroup} - -"
      "d ${vars.containers.dataDir}/searxng 2770 ${vars.username} ${localVars.searxng.mainGroup} - -"
      "d ${searxngDataDir} 2770 ${vars.username} ${localVars.searxng.mainGroup} - -"
      "d ${valkeyDataDir} 2770 ${vars.username} ${localVars.searxng-valkey.mainGroup} - -"
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
    networking.firewall.allowedTCPPorts = [8080];
    hm = {
      # https://seiarotg.github.io/quadlet-nix/home-manager-options.html
      virtualisation.quadlet = {
        containers = {
          searxng = {
            autoStart = true;
            serviceConfig = {
              RestartSec = "10";
              Restart = "always";
            };
            unitConfig = {
              Requires = "searxng-valkey.container";
            };
            containerConfig = {
              image = "docker.io/searxng/searxng:latest";
              publishPorts = ["8080:8080"];
              environments = {
                FORCE_OWNERSHIP = "false";
              };
              environmentFiles = [config.secrets.searxng.path];
              volumes = [
                "${searxngConfigDir}:/etc/searxng"
                "${searxngDataDir}:/var/cache/searxng"
              ];
              networks = ["searxng-internal" "searxng"];
              user = funcs.containers.mkUser "searxng" localVars.searxng.mainGroup;
              uidMaps =
                funcs.containers.mkUidMaps
                localVars.searxng.n;
              gidMaps =
                funcs.containers.mkGidMaps
                localVars.searxng.n
                ([localVars.searxng.mainGroup] ++ localVars.searxng.groups);
              addGroups =
                funcs.containers.mkAddGroups
                localVars.searxng.groups;
            };
          };
          searxng-valkey = {
            autoStart = true;
            serviceConfig = {
              RestartSec = "10";
              Restart = "always";
            };
            containerConfig = {
              image = "docker.io/valkey/valkey:latest";
              exec = "valkey-server --save 30 1 --loglevel warning";
              volumes = ["${valkeyDataDir}:/data"];
              networkAliases = ["valkey"];
              networks = ["searxng-internal"];
              user = funcs.containers.mkUser "valkey" localVars.searxng-valkey.mainGroup;
              uidMaps =
                funcs.containers.mkUidMaps
                localVars.searxng-valkey.n;
              gidMaps =
                funcs.containers.mkGidMaps
                localVars.searxng-valkey.n
                ([localVars.searxng-valkey.mainGroup] ++ localVars.searxng-valkey.groups);
              addGroups =
                funcs.containers.mkAddGroups
                localVars.searxng-valkey.groups;
            };
          };
          # https://github.com/searx/searx/discussions/1723#discussioncomment-832494
          # searxng-tor = {
          #   autoStart = true;
          #   serviceConfig = {
          #     RestartSec = "10";
          #     Restart = "always";
          #   };
          #   containerConfig = {
          #     image = "docker.io/osminogin/tor-simple:latest";
          #     networkAliases = [
          #       "tor"
          #     ];
          #     networks = [
          #       "searxng"
          #     ];
          #     userns = "keep-id";
          #   };
          # };
        };
        networks = {
          searxng = {};
          searxng-internal = {};
        };
      };
    };
  };
}
