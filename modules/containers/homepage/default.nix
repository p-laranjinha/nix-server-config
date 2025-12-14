{
  vars,
  funcs,
  config,
  lib,
  ...
}: let
  localVars = vars.containers.containers.homepage;

  homepageImage = "ghcr.io/gethomepage/homepage:v1.8.0@sha256:7dc099d5c6ec7fc945d858218565925b01ff8a60bcbfda990fc680a8b5cd0b6e";

  configDir = funcs.relativeToAbsoluteConfigPath ./config;
in {
  options.opts.containers.homepage.enable = lib.mkOption {
    default = config.opts.containers.enable;
    type = lib.types.bool;
  };

  config = lib.mkIf config.opts.containers.homepage.enable {
    systemd.tmpfiles.rules = [
      "d ${configDir} 2770 ${vars.username} ${localVars.mainGroup} - -"
    ];
    # Required to run homepage in rootless mode and it being able to read containers.
    users.users.${vars.username}.extraGroups = ["podman"];
    networking.firewall.allowedTCPPorts = [3000];
    hm = {
      virtualisation.quadlet = {
        containers = {
          homepage = {
            autoStart = true;
            serviceConfig = {
              RestartSec = "10";
              Restart = "always";
            };
            containerConfig = {
              image = homepageImage;
              publishPorts = ["3000:3000"];
              volumes = [
                "${configDir}:/app/config"
                # "/run/user/1000/podman/podman.sock:/var/run/docker.sock:ro"
                # TODO: Give homepage access to container info, this will
                #  probably require changing "podman.sock"'s group to something
                #  like 'podman-sock' that we can give to homepage and maybe
                #  other future containers.
              ];
              networks = ["homepage"];
              user = funcs.containers.mkUser "node" localVars.mainGroup;
              uidMaps = funcs.containers.mkUidMaps localVars.n;
              gidMaps =
                funcs.containers.mkGidMaps
                localVars.n
                ([localVars.mainGroup] ++ localVars.groups);
              addGroups =
                funcs.containers.mkAddGroups
                localVars.groups;
            };
          };
        };
        networks = {
          homepage = {};
        };
      };
    };
  };
}
