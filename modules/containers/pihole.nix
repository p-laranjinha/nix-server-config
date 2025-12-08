{
  vars,
  funcs,
  ...
}: let
  localVars = vars.containers.containers.pihole;
  piholeDataDir = "${vars.containers.dataDir}/pihole/etc";
in {
  # Allow non-root users to bind to privileged ports like 80.
  boot.kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 0;
  networking.firewall.allowedTCPPorts = [53];
  networking.firewall.allowedUDPPorts = [53];

  systemd.tmpfiles.rules = [
    "d ${vars.containers.dataDir}/pihole 2770 ${vars.username} ${localVars.mainGroup} - -"
    "d ${piholeDataDir} 2770 ${vars.username} ${localVars.mainGroup} - -"
  ];
  hm = {
    virtualisation.quadlet = {
      containers = {
        # https://github.com/pi-hole/docker-pi-hole
        pihole = {
          autoStart = true;
          serviceConfig = {
            RestartSec = "10";
            Restart = "always";
          };
          containerConfig = {
            image = "docker.io/pihole/pihole:latest";
            publishPorts = [
              "53:53/tcp"
              "53:53/udp"
              "80:80/tcp"
              "443:443/tcp"
            ];
            environments = {
              TZ = "Europe/Lisbon";
              # Not setting this variable will result in a random one.
              # Run `podman logs pihole | grep random` to find the random password.
              # Explicitly setting no password because it shouldn't be needed.
              FTLCONF_webserver_api_password = "";
              FTLCONF_dns_listeningMode = "ALL";
              PIHOLE_GID = "${funcs.containers.getContainerGid "pihole"}";
            };
            volumes = [
              "${piholeDataDir}:/etc/pihole"
            ];
            user = funcs.containers.mkUser "root" localVars.mainGroup;
            # addCapabilities = [
            #   # Allows binding to TCP/UDP sockets below 1024.
            #   "NET_BIND_SERVICE"
            # ];
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
