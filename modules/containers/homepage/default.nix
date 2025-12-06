{
  vars,
  funcs,
  ...
}: let
  homepage-config = funcs.relativeToAbsoluteConfigPath ./config;
in {
  systemd.tmpfiles.rules = [
    "d ${homepage-config} 2770 ${vars.username} ${vars.containers.containers.homepage.mainGroup} - -"
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
              "${homepage-config}:/app/config"
              # "/run/user/1000/podman/podman.sock:/var/run/podman.sock"
            ];
            networks = ["homepage"];
            user = funcs.containers.mkUser "node" vars.containers.containers.homepage.mainGroup;
            uidMaps = funcs.containers.mkUidMaps vars.containers.containers.homepage.n;
            gidMaps =
              funcs.containers.mkGidMaps
              vars.containers.containers.homepage.n
              ([vars.containers.containers.homepage.mainGroup] ++ vars.containers.containers.homepage.groups);
            addGroups =
              funcs.containers.mkAddGroups
              vars.containers.containers.homepage.groups;
          };
        };
      };
      networks = {
        homepage = {};
      };
    };
  };
}
