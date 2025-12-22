{
  vars,
  funcs,
  config,
  lib,
  ...
}: let
  localVars = vars.containers.containers.swag;
  swagImage = "lscr.io/linuxserver/swag:5.2.2";
  configDir = funcs.relativeToAbsoluteConfigPath ./config;
  defaultConfigDir = "${vars.containers.dataDir}/swag/config";
  modCacheDir = "${vars.containers.dataDir}/swag/modcache";
  symlinks = {
    "${defaultConfigDir}/dns-conf/porkbun.ini" = toString config.secrets.certbot-porkbun.path;
    "${defaultConfigDir}/tunnelconfig.yml" = "${configDir}/tunnelconfig.yml";
    "${defaultConfigDir}/nginx/site-confs/default.conf" = "${configDir}/default.conf";
    "${defaultConfigDir}/nginx/nginx.conf" = "${configDir}/nginx.conf";
    "${defaultConfigDir}/nginx/proxy-confs/dashboard.subdomain.conf" = "${configDir}/dashboard.subdomain.conf";
    "${defaultConfigDir}/nginx/proxy-confs/authelia.subdomain.conf" = "${configDir}/authelia.subdomain.conf";
    "${defaultConfigDir}/nginx/proxy-confs/homepage.subdomain.conf" = "${configDir}/homepage.subdomain.conf";
    "${defaultConfigDir}/nginx/proxy-confs/searxng.subdomain.conf" = "${configDir}/searxng.subdomain.conf";
    "${defaultConfigDir}/nginx/proxy-confs/immich.subdomain.conf" = "${configDir}/immich.subdomain.conf";
    "${defaultConfigDir}/nginx/proxy-confs/copyparty.subdomain.conf" = "${configDir}/copyparty.subdomain.conf";
    "${defaultConfigDir}/nginx/proxy-confs/lldap.subdomain.conf" = "${configDir}/lldap.subdomain.conf";
  };
  containerPUID = "1000";
  hostPUID = toString ((lib.toInt containerPUID) + vars.containers.uidGidCount * localVars.i + (builtins.elemAt config.users.users.${vars.username}.subUidRanges 0).startUid);
in {
  options.opts.containers.swag = {
    enable = lib.mkEnableOption "SWAG";
    autoStart = lib.mkEnableOption "SWAG auto-start";
  };

  config = lib.mkIf config.opts.containers.swag.enable {
    systemd.tmpfiles.rules =
      [
        "d ${vars.containers.dataDir}/swag 2770 ${vars.username} ${localVars.mainGroup} - -"
        "d ${defaultConfigDir} 2770 ${vars.username} ${localVars.mainGroup} - -"
        "d ${modCacheDir} 2770 ${vars.username} ${localVars.mainGroup} - -"
        "Z ${defaultConfigDir}/* 770 ${hostPUID} ${localVars.mainGroup} - -"
        # Symlinks aren't created if the destination directories have a different owner.
        "d ${defaultConfigDir}/dns-conf 770 ${vars.username} ${localVars.mainGroup} - -"
        "d ${defaultConfigDir}/nginx 770 ${vars.username} ${localVars.mainGroup} - -"
        "d ${defaultConfigDir}/nginx/site-confs 770 ${vars.username} ${localVars.mainGroup} - -"
        "d ${defaultConfigDir}/nginx/proxy-confs 770 ${vars.username} ${localVars.mainGroup} - -"

        "d ${configDir} 2770 ${vars.username} ${localVars.mainGroup} - -"
        "Z ${configDir}/* 770 ${vars.username} ${localVars.mainGroup} - -"
      ]
      ++ (map (x: "L+ ${x.name} - - - - ${x.value}") (lib.attrsToList symlinks));
    secrets = builtins.mapAttrs (_: value:
      {
        format = "binary";
        # Entire file.
        key = "";
        # Only the user and group can read and nothing else.
        mode = "0440";
        owner = vars.username;
        group = localVars.mainGroup;
      }
      // value) {
      # Random string:
      # `LC_ALL=C tr -dc 'A-Za-z0-9!#%&'\''()*+,-./:;<=>?@[\\]^_{|}~' </dev/urandom | head -c 32`
      # Automatically encrypt string with sops:
      # `sops --input-type binary -e <(LC_ALL=C tr -dc 'A-Za-z0-9!#%&'\''()*+,-./:;<=>?@[\\]^_{|}~' </dev/urandom | head -c 32) > <file path>`
      certbot-porkbun = {
        sopsFile = ./secrets/porkbun.ini;
        format = "ini";
      };
      swag-cloudflare = {
        sopsFile = ./secrets/cloudflare.env;
        format = "dotenv";
      };
    };
    networking.firewall.allowedTCPPorts = [80 443];
    hm = let
      networks = {
        # container = "network"
        searxng = "swag-searxng";
        homepage = "swag-homepage";
        immich = "swag-immich";
        copyparty = "swag-copyparty";
        authelia = "swag-authelia";
        lldap = "swag-lldap";
        # WARN: Everytime you change this, you need to remove
        #  '${defaultConfigDir}/nginx/resolver.conf' or else the
        #  new networks aren't used.
      };
    in {
      virtualisation.quadlet = {
        containers =
          {
            swag = funcs.containers.mkConfig "root" localVars {
              autoStart = config.opts.containers.swag.autoStart;
              serviceConfig = {
                RestartSec = "10";
                Restart = "always";
              };
              containerConfig = {
                image = swagImage;
                publishPorts = [
                  "443:443"
                  "80:80"
                ];
                environments = {
                  PUID = containerPUID;
                  PGID = funcs.containers.getContainerGid localVars.mainGroup;
                  TZ = "Europe/Lisbon";
                  URL = "orangepebble.net";
                  SUBDOMAINS = "wildcard";
                  VALIDATION = "dns";
                  DNSPLUGIN = "porkbun";
                  DOCKER_MODS = "linuxserver/mods:swag-dashboard|linuxserver/mods:swag-dbip|linuxserver/mods:universal-cloudflared";
                  # https://www.linuxserver.io/blog/zero-trust-hosting-and-reverse-proxy-via-cloudflare-swag-and-authelia
                  CF_TUNNEL_NAME = "server";
                  FILE__CF_TUNNEL_CONFIG = "/config/tunnelconfig.yml";
                };
                environmentFiles = [(toString config.secrets.swag-cloudflare.path)];
                addHosts = ["orangepebble.net:127.0.0.1"];
                volumes =
                  [
                    "${defaultConfigDir}:/config"
                    "${modCacheDir}:/modcache"
                  ]
                  ++ (map (x: "${x}:${x}") (builtins.attrValues symlinks));
                networks = builtins.attrValues networks;
                addCapabilities = ["NET_ADMIN"];
              };
            };
          }
          // (builtins.mapAttrs (_: value: {containerConfig.networks = [value];}) networks);
        networks = builtins.listToAttrs (map (x: {
          name = x;
          value = {};
        }) (builtins.attrValues networks));
      };
    };
  };
}
