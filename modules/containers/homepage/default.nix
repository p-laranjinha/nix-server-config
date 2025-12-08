{
  vars,
  funcs,
  ...
}: let
  localVars = vars.containers.containers.homepage;
  homepageConfigDir = funcs.relativeToAbsoluteConfigPath ./config;
in {
  systemd.tmpfiles.rules = [
    "d ${homepageConfigDir} 2770 ${vars.username} ${localVars.mainGroup} - -"
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
            image = "ghcr.io/gethomepage/homepage:latest";
            publishPorts = ["3000:3000"];
            volumes = [
              "${homepageConfigDir}:/app/config"
              # "/run/user/1000/podman/podman.sock:/var/run/podman.sock"
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
}
