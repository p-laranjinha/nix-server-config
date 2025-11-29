{...}: {
  hm = {
    services.syncthing = {
      # WARNING: If something is wrong, syncthing will just not have any
      #  devices or folders.
      # INFO: Versioning cleanup interval uses a different method which
      #  nixpkgs doesn't seem to support.
      enable = true;
      settings = {
        devices = {
          "phone".id = "R2RNYGN-BZPUWLZ-6OEOT77-ALGBSJP-MD2JPBY-AOY2T72-UX25SEB-H47LVAO";
          "tablet".id = "XR6AZSI-APGKKIB-LWMMCKW-6E63TBX-KFBSLVG-7JYURKQ-TZNGESZ-IVNNDQ5";
          "desktop".id = "SHD6TV6-OO7AOMT-GHU2YL4-HXTS2VR-AYCKKX6-JAK7LCF-2NWM47E-MHR7GAS";
        };
        folders = {
          "default" = {
            id = "default";
            path = "~/sync/default";
            devices = [
              "phone"
              "tablet"
              "desktop"
            ];
            versioning = {
              type = "staggered";
              params = {
                #cleanInterval = "604800"; # clean once per week
                maxAge = "0"; # 1 year
              };
            };
          };
          "obsidian-vaults" = {
            id = "obsidian-vaults";
            path = "~/sync/obsidian-vaults";
            devices = [
              "phone"
              "tablet"
              "desktop"
            ];
            versioning = {
              type = "staggered";
              #cleanupIntervalS = "604800"; # clean once per week
              params.maxAge = "0"; # forever
            };
          };
          "music" = {
            id = "music";
            path = "~/sync/music";
            devices = [
              "phone"
              "desktop"
            ];
            versioning = {
              type = "staggered";
              #cleanupIntervalS = "604800"; # clean once per week
              params.maxAge = "31536000"; # 1 year
            };
          };
          "tachiyomi-backup" = {
            id = "tachiyomi-backup";
            path = "~/sync/tachiyomi-backup";
            devices = [
              "phone"
              "tablet"
              "desktop"
            ];
          };
          "WIT" = {
            id = "wit";
            path = "~/sync/WIT";
            devices = [
              "phone"
              "desktop"
            ];
          };
        };
      };
    };
    systemd.user.services.syncthing.environment.STNODEFAULTFOLDER = "true";
  };
}
