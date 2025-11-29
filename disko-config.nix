# ZFS expansion doesn't seem to work with disko, so to add more drives in the
#  future, you'll have to use the regular commands.
# https://discourse.nixos.org/t/zfs-expansion-weirdness/71167
#  Expansion can also be a bit weird but functional enough, it doesn't correctly
#   update the new available disk space so most software reports that it
#   has less space than it actually has. Use `zpool list` for a more accurate
#   reading of available space. Additionally, files that existed previously to
#   the expansion use more storage than required, for example with RAIDZ2, if
#   you expand from 3 to 4 drives, the old files will effectively take almost
#   1.5x the space of new ones.
#  I've tried using github:iBug/zfs-recompress.py to try to reset how much space
#   old files take but it didn't work. Copying the file and pasting it with a
#   different name, deleting the old file, and copying the new file and pasting it
#   with the old name also didn't work.
# Disko probably can't be used to replace faulty drives either.
{
  disko.devices = {
    # Use id names instead of /dev/sdX as using the non-id names may lead to
    #  import problems.
    # Consider using 'by-partuuid' or 'by-uuid' instead of 'by-id' and those are
    #  more consistent but only work if zfs is setup on partitions instead of
    #  whole disks.
    # To get device ids: `ls -lh /dev/disk/by-***/`
    disk = {
      root = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-Lexar_SSD_NM620_256GB_QAG282R016101P1157";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = ["umask=0077"];
              };
            };
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "zroot";
              };
            };
            swap = {
              # https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/7/html/storage_administration_guide/ch-swapspace
              # 1.5x the RAM so it has space for hibernation plus whatever
              #  may have already been in swap.
              size = "48G";
              content = {
                type = "swap";
                discardPolicy = "both";
                resumeDevice = true; # Resume from hibernation from here.
              };
            };
          };
        };
      };
      data1 = {
        type = "disk";
        device = "/dev/disk/by-id/ata-ST2000NM0011_Z1P6911G";
        content = {
          type = "gpt";
          partitions = {
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "zdata";
              };
            };
            # Added a padding partition, so there's less risk of the
            #  'device is too small' error when apending a new disk,
            #  even if they should be the same size as the current ones.
            padding.size = "64M";
          };
        };
      };
      data2 = {
        type = "disk";
        device = "/dev/disk/by-id/ata-ST2000NM0011_Z1P68QSB";
        content = {
          type = "gpt";
          partitions = {
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "zdata";
              };
            };
          };
        };
      };
      data3 = {
        type = "disk";
        device = "/dev/disk/by-id/ata-ST2000NM0011_Z1P68X09";
        content = {
          type = "gpt";
          partitions = {
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "zdata";
              };
            };
          };
        };
      };
      data4 = {
        type = "disk";
        device = "/dev/disk/by-id/ata-ST2000VX008-2E3164_Z527V6R9";
        content = {
          type = "gpt";
          partitions = {
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "zdata";
              };
            };
          };
        };
      };
    };
    # Not doing encryption because I feel like it wouldn't be worth the hassle.
    # It's not like this will be a laptop and easy to steal/lose. But it would
    #  add the danger of losing the password, add overhead, and other
    #  configuration hassle.
    # Just remember to wipe or destroy the drives if you sell them or throw them away.
    #
    # https://jrs-s.net/2018/08/17/zfs-tuning-cheat-sheet/
    # https://wiki.archlinux.org/title/Install_Arch_Linux_on_ZFS
    zpool = {
      zroot = {
        type = "zpool";
        # https://openzfs.github.io/openzfs-docs/man/v2.4/7/zfsprops.7.html
        rootFsOptions = {
          # Enables the use of posix acl (getfacl, setfacl) stored as extended
          #  attributes.
          acltype = "posixacl";
          # Improves performance specially for many small files, by changing how
          #  extended attributes are saved. Causes attributes to only be
          #  readable with the ZFS-on-Linux OpenZFS implementation.
          xattr = "sa";
          # Recommended with xattr=sa.
          dnodesize = "auto";
          # Disables the 'Accessed' attribute so that files aren't updated every
          #  time they're opened or ls'd.
          # If you want a compromise of only updating the 'Accessed' attribute
          #  after 24h of the last update, set atime=on and relatime=on.
          atime = "off";
          # Compression actually improves speed at the cost of some CPU usage.
          # lz4 is very slightly better in read speeds but loses at everything else.
          compression = "zstd";
          # Better interoperability between some filesystem filenames.
          normalization = "formD";
          # https://superuser.com/a/538580
          # Makes it so that files in /dev/*** properly adhere to permissions.
          devices = "off";
          # Disable auto snapshots by default, so they only apply when
          #  specified on the dataset.
          # Used by services.zfs.autoSnapshot options.
          "com.sun:auto-snapshot" = "false";
          # Deduplication is very resource intensive and compression should be
          #  used instead. It is off by default.
          # dedup = "off";
        };
        # https://openzfs.github.io/openzfs-docs/man/v2.4/7/zpoolprops.7.html
        options = {
          # Use:
          # `lsblk -S -o NAME,PHY-SEC`
          # `nvme id-ns /dev/nvmeXnY -H | grep "LBA Format"`
          # To get the the physical sector size of SATA/NVMe drives.
          # ashift=12 is for 4096-byte sectors.
          # Even though my commands above returned 512 for most drives, I'll keep
          #  ashift=12 because drives can apparently report the wrong size, and
          #  having a lower ashift is worse than a higher ashift (lower impacts
          #  performance, higher impacts capacity). Additionally, this value
          #  will future-proof me more for possible extra drives.
          ashift = "12";
        };
        datasets = {
          root = {
            type = "zfs_fs";
            mountpoint = "/";
          };
          # Not sure why /nix and /var have their own datasets, but every example
          #  I see does this and I don't see any downside, so might as well.
          nix = {
            type = "zfs_fs";
            mountpoint = "/nix";
          };
          var = {
            type = "zfs_fs";
            mountpoint = "/var";
          };
        };
      };
      zdata = {
        type = "zpool";
        mode = "raidz2";
        rootFsOptions = {
          acltype = "posixacl";
          xattr = "sa";
          dnodesize = "auto";
          atime = "off";
          compression = "zstd";
          normalization = "formD";
          devices = "off";
          "com.sun:auto-snapshot" = "false";
          # Having mountpoint as legacy makes it so that systemd handles all mounting,
          #  and so the fileSystems option becomes required.
          # Setting this because zfs and systemd were having problems with both trying
          #  to mount /home.
          # This also requires additional steps to the initial setup to mount /home
          #  before running nixos-install.
          mountpoint = "legacy";
        };
        options = {
          ashift = "12";
        };
        datasets = {
          home = {
            type = "zfs_fs";
            #mountpoint = "/home";
            # Only using snapshots on home because everything else should be
            #  handled by NixOS.
            options."com.sun:auto-snapshot" = "true";
            # I think this is creating an initial blank snapshot.
            postCreateHook = "zfs list -t snapshot -H -o name | grep -E '^zdata/home@blank$' || zfs snapshot zdata/home@blank";
          };
        };
      };
    };
  };
}
