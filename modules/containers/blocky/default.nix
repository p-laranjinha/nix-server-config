# Info about Blocky, DNS, and routers at the end of the file.
# On my router I've set:
#  - Primary DNS on the Internet section to Mullvad
#  - Secondary DNS on the Internet section to Control D
#  - Default gateway to 192.168.1.2 and IP address pool 192.168.1.3-192.168.1.253
#    - The plan was to keep 192.168.1.1 my ISP router's IP, but I didn't figure
#    out how to make it accessible. And yes, the ISP router's web UI is still
#    available, I had to manually disable WIFI after setting bridge mode to 1
#    port.
#  - Reserved IP address 192.168.1.3 to the desktop.
#  - Reserved IP address 192.168.1.4 to the server.
#  - Reserved IP address 192.168.1.5 to the printer.
{
  vars,
  funcs,
  config,
  lib,
  ...
}: let
  localVars = vars.containers.containers.blocky;

  blockyImage = "ghcr.io/0xerr0r/blocky:v0.28.2@sha256:5f84a54e4ee950c4ab21db905b7497476ece2f4e1a376d23ab8c4855cabddcba";

  blockyConfigFile = funcs.relativeToAbsoluteConfigPath ./config.yaml;
in {
  options.opts.containers.blocky.enable = lib.mkOption {
    default = config.opts.containers.enable;
    type = lib.types.bool;
  };

  config = lib.mkIf config.opts.containers.blocky.enable {
    # Allow non-root users to bind to privileged ports like 80.
    boot.kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 0;
    networking.firewall.allowedTCPPorts = [53];
    networking.firewall.allowedUDPPorts = [53];
    hm = {
      virtualisation.quadlet = {
        containers = {
          # https://0xerr0r.github.io/blocky/latest/
          blocky = {
            autoStart = true;
            serviceConfig = {
              RestartSec = "10";
              Restart = "always";
            };
            containerConfig = {
              image = blockyImage;
              publishPorts = [
                "53:53/tcp"
                "53:53/udp"
                "4000:400/tcp"
              ];
              environments = {
                TZ = "Europe/Lisbon";
              };
              volumes = [
                "${blockyConfigFile}:/app/config.yml:ro"
              ];
              # I think the blocky container might just be a single binary, but
              #  the image layers (I think equivalent to a compose file) sets
              #  user to 100. I don't think it uses any group though.
              uidMaps = funcs.containers.mkUidMaps localVars.n;
            };
          };
        };
      };
    };
  };
}
# I've chosen Blocky as my DNS server instead of Pi-hole or TechnitiumDNS
#  mostly because it was created with containers in mind and all its
#  configuration is set in a file.
# I'm using the blocklists from 'https://github.com/hagezi/dns-blocklists' as
#  they seem popular and well regarded. This is also where I found the DNS
#  server alternatives.
# I've thought about hosting a recursive DNS myself, so that I'm not dependent
#  on public DNS (that may track personal information and block websites I may
#  want to visit, like piracy ones), but that's apparently pretty resource
#  intensive, can be slow, and I don't want my family's internet to be
#  dependent on whether my server is working.
# Although the internet not being dependent on the server would require not
#  setting a secondary DNS server on my router, and I'm not sure how that would
#  affect url redirections to my server.
# I've found some public and free DNS servers that both blocked ads/etc and
#  seemed private:
#   - Control D : https://controld.com/free-dns
#   - Mullvad : https://mullvad.net/en/help/dns-over-https-and-dns-over-tls
#   - Quad9 : https://quad9.net
#   - AdGuard : https://adguard-dns.io/en/public-dns.html
# Of these free DNS servers the ones I think are the most performant are (in
#  order): Control D, Mullvad, Quad9, AdGuard.
#  Mullvad is by far the most consistent, but Control D is faster most of the
#   times with some rarer slow outliers, and Quad9 wildy fluctuates between
#   being the faster or the slowest between all others.
#  For some reason I lean towards Mullvad, even though it isn't the fastest,
#   but I'll primarily use Control D.
# https://www.reddit.com/r/pihole/comments/1ajunoc/whats_the_difference_between_dns_in_dhcp_server/
#  I can set DNS servers on two different spots in my router, on the DHCP server
#  and on the Internet section. The difference between the 2 is that those on
#  the Internet section are WAN only (can't use private addresses like one to
#  this server), and the ones in the DHCP server come before it, if DNS servers
#  aren't set in the DHCP server, the router announces itself as the DNS server
#  and redirects to the ones in the Internet section.
# Now, if I want the absolute certainty that all DNS requests pass through my
#  server, I have to set all DNS servers on the DHCP server to my server. But
#  this makes it so that when the server goes down, DNS is down, and there is
#  no internet. So if I want redundancy, I'll need to leave the secondary DNS
#  server field empty on the DHCP server, but depending on how the client (PC,
#  phone, etc) handle primary and secondary DNS servers, the DNS server on my
#  server may never be used.

