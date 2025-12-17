{
  vars,
  funcs,
  lib,
  config,
  ...
}: let
  localVars = vars.containers.containers.copyparty;

  copypartyImage = "ghcr.io/9001/copyparty-ac:1.19.21@sha256:b1f8be53f068ad37f583cfd93b6a3611472ee8c30e98177389629631a4b6b4ca";

  # Making a new config directory separate from /cfg, because other things
  #  are stored in /cfg that I don't want in the repo.
  copypartyConfigDir = funcs.relativeToAbsoluteConfigPath ./config;
  copypartyCfgDir = "${vars.containers.dataDir}/copyparty/cfg";
  copypartyHistsDir = "${vars.containers.dataDir}/copyparty/hists";
in {
  options.opts.containers.copyparty = {
    enable = lib.mkEnableOption "copyparty";
    autoStart = lib.mkEnableOption "copyparty auto-start";
  };

  config = lib.mkIf config.opts.containers.copyparty.enable {
    systemd.tmpfiles.rules = [
      "d ${copypartyConfigDir} 2770 ${vars.username} ${localVars.mainGroup} - -"
      "d ${vars.containers.dataDir}/copyparty 2770 ${vars.username} ${localVars.mainGroup} - -"
      "d ${copypartyCfgDir} 2770 ${vars.username} ${localVars.mainGroup} - -"
      "d ${copypartyHistsDir} 2770 ${vars.username} ${localVars.mainGroup} - -"

      "Z ${copypartyConfigDir} 2770 ${vars.username} ${localVars.mainGroup} - -"
      "Z ${vars.containers.dataDir}/copyparty 2770 ${vars.username} ${localVars.mainGroup} - -"
    ];
    hm = {
      virtualisation.quadlet = {
        containers = {
          copyparty = funcs.containers.mkConfig "1000" localVars {
            autoStart = config.opts.containers.copyparty.autoStart;
            containerConfig = {
              image = copypartyImage;
              # Modified the entry pointfound here:
              #  https://github.com/9001/copyparty/blob/hovudstraum/scripts/docker/Dockerfile.ac
              exec = "-c /z/initcfg -c /copyparty-config";
              publishPorts = [
                "3923:3923"
              ];
              volumes = [
                "${vars.containers.publicDir}:/w"
                "${copypartyConfigDir}:/copyparty-config"
                "${copypartyCfgDir}:/cfg"
                "${copypartyHistsDir}:/hists"
              ];
            };
          };
        };
      };
    };
  };
}
