{
  vars,
  funcs,
  config,
  lib,
  ...
}:
let
  localVars = vars.containers.containers;

  # Find new versions at:
  #  https://github.com/karakeep-app/karakeep/releases
  karakeepVersion = "0.31.0";
  karakeepImage = "ghcr.io/karakeep-app/karakeep:${karakeepVersion}";
  # Find new versions for the following two at:
  #  https://github.com/karakeep-app/karakeep/blob/main/docker/docker-compose.yml
  chromeImage = "gcr.io/zenika-hub/alpine-chrome:124";
  meilisearchImage = "getmeili/meilisearch:v1.37.0";

  karakeepDataDir = "${vars.containers.dataDir}/karakeep/data";
  meilisearchDataDir = "${vars.containers.dataDir}/karakeep/meilisearch-data";
in
{
  options.opts.containers.karakeep = {
    enable = lib.mkEnableOption "karakeep";
    autoStart = lib.mkEnableOption "karakeep auto-start";
  };

  config = lib.mkIf config.opts.containers.karakeep.enable {
    systemd.tmpfiles.rules = [
      "d ${vars.containers.dataDir}/karakeep 2770 ${vars.username} ${localVars.karakeep.mainGroup} - -"
      "d ${karakeepDataDir} 2770 ${vars.username} ${localVars.karakeep.mainGroup} - -"
      "Z ${karakeepDataDir}/* 770 ${vars.username} ${localVars.karakeep.mainGroup} - -"
      "d ${meilisearchDataDir} 2770 ${vars.username} ${localVars.karakeep-meilisearch.mainGroup} - -"
      "Z ${meilisearchDataDir}/* 770 ${vars.username} ${localVars.karakeep-meilisearch.mainGroup} - -"
    ];

    secrets =
      builtins.mapAttrs
        (
          _: value:
          {
            format = "binary";
            # Entire file.
            key = "";
            # Only the user and group can read and nothing else.
            mode = "0440";
            owner = vars.username;
            group = localVars.karakeep-meilisearch.mainGroup;
          }
          // value
        )
        {
          karakeep-dotenv = {
            sopsFile = ./.env;
            format = "dotenv";
          };
        };
    hm = {
      virtualisation.quadlet = {
        containers = {
          karakeep = funcs.containers.mkConfig "root" localVars.karakeep {
            inherit (config.opts.containers.karakeep) autoStart;
            containerConfig = {
              image = karakeepImage;
              environments = {
                TZ = "Europe/Lisbon";
                DATA_DIR = "/data";
                KARAKEEP_VERSION = karakeepVersion;
                NEXTAUTH_URL = "https://bookmarks.orangepebble.net";
                MEILI_ADDR = "http://karakeep-meilisearch:7700";
                BROWSER_WEB_URL = "http://karakeep-chrome:9222";
                DISABLE_PASSWORD_AUTH = "true";
                OAUTH_AUTO_REDIRECT = "true";
                OAUTH_WELLKNOWN_URL = "https://auth.orangepebble.net/.well-known/openid-configuration";
                OAUTH_CLIENT_ID = "karakeep";
                OAUTH_PROVIDER_NAME = "Authelia";
              };
              environmentFiles = [
                config.secrets.karakeep-dotenv.path
              ];
              volumes = [
                "${karakeepDataDir}:/data"
              ];
              networks = [ "karakeep" ];
            };
          };
          karakeep-chrome = funcs.containers.mkConfig "chrome" localVars.karakeep-chrome {
            inherit (config.opts.containers.karakeep) autoStart;
            containerConfig = {
              image = chromeImage;
              exec = [
                "--no-sandbox"
                "--disable-gpu"
                "--disable-dev-shm-usage"
                "--remote-debugging-address=0.0.0.0"
                "--remote-debugging-port=9222"
                "--hide-scrollbars"
              ];
              environments = {
                TZ = "Europe/Lisbon";
              };
              networks = [ "karakeep" ];
            };
          };
          karakeep-meilisearch = funcs.containers.mkConfig "root" localVars.karakeep-meilisearch {
            inherit (config.opts.containers.karakeep) autoStart;
            containerConfig = {
              image = meilisearchImage;
              environments = {
                TZ = "Europe/Lisbon";
                MEILI_NO_ANALYTICS = "true";
              };
              environmentFiles = [
                config.secrets.karakeep-dotenv.path
              ];
              volumes = [
                "${meilisearchDataDir}:/meili_data"
              ];
              networks = [ "karakeep" ];
            };
          };
        };
        networks.karakeep = { };
      };
    };
  };
}
