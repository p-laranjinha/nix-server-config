{
  vars,
  funcs,
  ...
}: let
  localVars = vars.containers.containers.copyparty;
  copypartyConfigDir = funcs.relativeToAbsoluteConfigPath ./config;
  copypartyHistsDir = "${vars.containers.dataDir}/copyparty/hists";
in {
  systemd.tmpfiles.rules = [
    "d ${copypartyConfigDir} 2770 ${vars.username} ${localVars.mainGroup} - -"
    "d ${vars.containers.dataDir}/copyparty 2770 ${vars.username} ${localVars.mainGroup} - -"
    "d ${copypartyHistsDir} 2770 ${vars.username} ${localVars.mainGroup} - -"
  ];
  hm = {
    virtualisation.quadlet = {
      containers = {
        copyparty = {
          autoStart = true;
          serviceConfig = {
            RestartSec = "10";
            Restart = "always";
          };
          containerConfig = {
            image = "docker.io/copyparty/ac:latest";
            publishPorts = [
              "3923:3923"
            ];
            volumes = [
              "${copypartyConfigDir}:/cfg"
              "${vars.containers.publicDir}:/w"
              "${copypartyHistsDir}:/hists"
            ];
            user = funcs.containers.mkUser "1000" localVars.mainGroup;
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
    };
  };
}
