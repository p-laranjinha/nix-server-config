{
  inputs,
  lib,
  vars,
  funcs,
  ...
}: let
  # Easy way to disable all the container related things, because when I'm
  #  adding and experimenting with containers it's nice to have a way to reset
  #  to a clean slate.
  # I've tried doing the same with the option 'opts.containers.enable' but it
  #  didn't seem to reset properly. Especially the subgids and subuids.
  # WARN: If things still don't work, try `podman system reset`.
  enable = true;
in
  if enable
  then {
    imports =
      [inputs.quadlet-nix.nixosModules.quadlet]
      ++ lib.attrValues (lib.modulesIn ./.);

    # Rebuilding with multiple containers may fail because running the containers
    #  and their configuration may take too long. Rebuilding a second time may
    #  also work.
    # WARN: Sometimes when rebuilding fails, to remove the container services,
    #  the files at '~/.config/systemd/user/' and '~/.config/containers/systemd/'
    #  have to be deleted manually.
    #  Enabling and disabling the containers in this config also works.
    # WARN: Additionally, rebuilding failing can also fail to remove containers
    #  from autostart.
    #  These can be removed manually in '~/.config/systemd/user/default.target.wants/'.
    opts.containers = {
      searxng.enable = true;
      searxng.autoStart = true;
      homepage.enable = true;
      homepage.autoStart = true;
      blocky.enable = true;
      blocky.autoStart = true;
      copyparty.enable = true;
      copyparty.autoStart = true;
      immich.enable = true;
      immich.autoStart = true;
      swag.enable = true;
      swag.autoStart = true;
    };

    # Run 'systemd-tmpfiles' to apply these rules manually.
    systemd.tmpfiles.rules = [
      "d ${vars.containers.dataDir} 2770 ${vars.username} users - -"
      "d ${vars.containers.publicDir} 2770 ${vars.username} public - -"
    ];

    # Allow non-root users to bind to privileged ports like 80.
    boot.kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 0;

    systemd.services.${"home-manager-${vars.username}"}.serviceConfig = {
      # Extending timeout because starting containers can take quite a bit.
      TimeoutStartSec = lib.mkForce "30m";
    };

    # Enable podman & podman systemd generator.
    virtualisation.quadlet.enable = true;
    users.users.${vars.username} = {
      # Required for auto start before user login.
      linger = true;
      # Required for rootless container with multiple users.
      # autoSubUidGidRange = true;
      subUidRanges = [
        {
          count = 1000000;
          startUid = 100000;
        }
      ];
      subGidRanges = [
        {
          count = 1000000;
          startGid = 100000;
        }
        {
          count = lib.length vars.containers.groups;
          inherit (vars.containers) startGid;
        }
      ];
    };
    users.groups = funcs.containers.mkGroups vars.containers.groups;
    hm = {
      imports = [inputs.quadlet-nix.homeManagerModules.quadlet];
      virtualisation.quadlet = {
        autoEscape = true; # Will be default in the future.
      };
    };
  }
  else {}
# Groups aren't deleted automatically because Nix doesn't know what files are
#  owned by the groups.
# So if you wan't to remove or change group order, you'll have to manually
#  remove the group using 'sudo groupdel <group>' and change the owner group of
#  the files/folders that need it.
# An easy way to change owner groups to every file/folder that needs it is by
#  running 'sudo find / -gid <OLD_GID> -exec chgrp <NEW_GID> {} +' before
#  running 'nixos-rebuild switch'.
#
# Container options:
#  https://seiarotg.github.io/quadlet-nix/home-manager-options.html
#
# Volumes don't support symlinks, so when I want to volume folders in this repo
#  it has to be directly.
#
# The following references gids but the same applies to uids:
# gidmaps don't directly map my host's groups to the container's, they map a
#  user's subgids. For example, if the subgids are from 100000-..., the
#  '0:1:2000' maps the host's 100000-102000 to the containers 0-2000.
#  The exception is '_:0:_' as that maps the host's current user's primary group.
# If you want to share a group between the container and the host (without
#  relying on the 'run.oci.keep_original_groups' annotation or on the
#  'keep-groups' groupAdd option, as that adds all of the host user's groups
#  to the containers), you'll have to create a group on the host and add it to
#  the user and user's subgids. For example, if you add the group 1001, the
#  gidmap '9999:1:1' would map the host's 1001 to the container's 9999, and the
#  default subgids would start to map from '_:2:_'.
#  I think the added subgid comes before the default ones because it is a
#  smaller gid, but I haven't tested it.
# Now, gidmaps are incompatible with the 'userns' option, so if you decide you
#  want to use it, you can't forget to map enough gids for all the groups the
#  container needs. Examples I've seen online map 1000 gids (ex: '0:1:1000'),
#  but 100 is probably already more than enough for most cases.
# Use 'cat /etc/group' to see all groups and 'cat /etc/passwd' to see all users.
# Another thing I haven't tested is if there is any problem with multiple
#  containers being mapped the same gids. I think it will run with no problems
#  but the containers will share the same host gids, which I'd imagine is not
#  the best for security.
#  Either way, there are enough gids to give each container a unique set, so
#  might as well just in case.
#
# These links are good sources of a simpler way to setup podman containers:
#  https://www.redhat.com/en/blog/rootless-podman-user-namespace-modes
#  https://www.redhat.com/en/blog/supplemental-groups-podman-containers
#
# https://www.redhat.com/en/blog/user-flag-rootless-containers
# I'm also using 'user="<user>"' to make the container not use the root user,
#  as even in rootless mode it still has more permissions. I find a valid user
#  by running 'podman exec -it <container> cat /etc/passwd' to list all users
#  (the best one to use is probably the last one).
# For containers that need to be root to run some utils, I'll remove the user
#  option but drop root's capabilities instead. Use the following to get the
#  capabilities of the current user: 'podman top <container> capeff'
# Changing the user or removing root capabilities makes the 'U' volume option
#  stop working, which then requires sharing host groups with write permissions.
#
# I'm using 'systemd.tmpfiles.rules' to automatically create directories and
#  set their permissions. Using 2___ permissions, makes it so the files created
#  in that directory inherit the group, so I can hopefully at least read the
#  files outside the container.
