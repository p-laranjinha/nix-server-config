# https://github.com/immich-app/immich
{
  vars,
  funcs,
  lib,
  config,
  ...
}: let
  localVars = vars.containers.containers;
  # Obtained versions from the release 'docker-compose.yml'.
  # If you can't find the 'sha' use `podman images --digest`.
  immichImage = "ghcr.io/immich-app/immich-server:v2.3.1@sha256:f8d06a32b1b2a81053d78e40bf8e35236b9faefb5c3903ce9ca8712c9ed78445";
  redisImage = "ghcr.io/valkey-io/valkey:8.1.5@sha256:e6519c81133f55170dcaf1c7711dea0770dc756a7aef0cb919204c8d6e325776";
  databaseImage = "ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0@sha256:bcf63357191b76a916ae5eb93464d65c07511da41e3bf7a8416db519b40b1c23";
  machineLearningImage = "ghcr.io/immich-app/immich-machine-learning:v2.3.1@sha256:379e31b8c75107b0af8141904baa8cc933d7454b88fdb204265ef11749d7d908";

  immichUploadDir = "${vars.containers.publicDir}/images";
  databaseDataDir = "${vars.containers.dataDir}/immich/database/data";
  machineLearningCacheDir = "${vars.containers.dataDir}/immich/machine-learning/cache";

  env = {
    TZ = "Europe/Lisbon";
    DB_USERNAME = "postgres";
    DB_PASSWORD = "postgres"; # TODO: change to use a sops encrypted password
    DB_DATABASE_NAME = "immich";
  };
in {
  options.opts.containers.immich = {
    enable = lib.mkEnableOption "Immich";
    autoStart = lib.mkEnableOption "Immich auto-start";
  };

  config = lib.mkIf config.opts.containers.immich.enable {
    systemd.tmpfiles.rules = [
      "d ${immichUploadDir} 2770 ${vars.username} public - -"

      "d ${vars.containers.dataDir}/immich 2770 ${vars.username} ${localVars.immich.mainGroup} - -"

      "d ${vars.containers.dataDir}/immich/database 2770 ${vars.username} ${localVars.immich-database.mainGroup} - -"
      "d ${databaseDataDir} 2770 ${vars.username} ${localVars.immich-database.mainGroup} - -"

      "d ${vars.containers.dataDir}/immich/machine-learning 2770 ${vars.username} ${localVars.immich-machine-learning.mainGroup} - -"
      "d ${machineLearningCacheDir} 2770 ${vars.username} ${localVars.immich-machine-learning.mainGroup} - -"

      "Z ${immichUploadDir} 2770 ${vars.username} public - -"
      "Z ${vars.containers.dataDir}/immich 2770 ${vars.username} ${localVars.immich.mainGroup} - -"
      "Z ${vars.containers.dataDir}/immich/database 2770 ${vars.username} ${localVars.immich-database.mainGroup} - -"
      "Z ${vars.containers.dataDir}/immich/machine-learning 2770 ${vars.username} ${localVars.immich-machine-learning.mainGroup} - -"
    ];
    hm = {
      virtualisation.quadlet = {
        # https://github.com/linux-universe/immich-podman-quadlets
        containers = {
          immich = funcs.containers.mkConfig "node" localVars.immich {
            autoStart = config.opts.containers.immich.autoStart;
            # This makes it so that the other containers can have autoStart as
            #  false, but even so this container will start before the ones
            #  it depends on and fail at least once per startup.
            unitConfig = {
              Requires = "immich-redis.container immich-database.container";
              Wants = "immich-machine-learning.container";
            };
            containerConfig = {
              image = immichImage;
              publishPorts = ["2283:2283"];
              environments = env;
              volumes = [
                "${immichUploadDir}:/data"
                "/etc/localtime:/etc/localtime:ro"
              ];
              networks = ["immich"];
            };
          };
          immich-machine-learning = funcs.containers.mkConfig "root" localVars.immich-machine-learning {
            containerConfig = {
              image = machineLearningImage;
              volumes = [
                "${machineLearningCacheDir}:/cache"
              ];
              networks = ["immich"];
              networkAliases = ["immich-machine-learning"];
              dropCapabilities = vars.containers.rootCapabilities;
            };
          };
          immich-redis = funcs.containers.mkConfig "valkey" localVars.immich-redis {
            containerConfig = {
              image = redisImage;
              networks = ["immich"];
              networkAliases = ["redis"];
            };
          };
          immich-database = funcs.containers.mkConfig "postgres" localVars.immich-database {
            containerConfig = {
              image = databaseImage;
              environments = {
                POSTGRES_USER = env.DB_USERNAME;
                POSTGRES_PASSWORD = env.DB_PASSWORD;
                POSTGRES_DB = env.DB_DATABASE_NAME;
                POSTGRES_INITDB_ARGS = "--data-checksums";
                DB_STORAGE_TYPE = "HDD";
              };
              volumes = [
                "${databaseDataDir}:/var/lib/postresql/data"
              ];
              shmSize = "128mb";
              networks = ["immich"];
              networkAliases = ["database"];
            };
          };
        };
        networks.immich = {};
      };
    };
  };
}
