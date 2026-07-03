{ config, pkgs, hostVars, ... }:

{
  boot.kernel.sysctl = {
    # NAT
    "net.ipv4.ip_forward" = 1;

    # Disable ipv6
    "net.ipv6.conf.all.disable_ipv6" = 1;
    "net.ipv6.conf.default.disable_ipv6" = 1;
    "net.ipv6.conf.lo.disable_ipv6" = 1;
  };

  networking = {

    # Routing
    nftables = {
      enable = true;
      ruleset = ''
        flush ruleset

        # Mark servers for lower qos
        table inet mangle {
            chain qos_marking {
                type filter hook postrouting priority -150;

                ip saddr ${hostVars.ipServer1} meta mark set 5;
                ip daddr ${hostVars.ipServer1} meta mark set 5;
                ip saddr ${hostVars.ipServer2} meta mark set 5;
                ip daddr ${hostVars.ipServer2} meta mark set 5;
            }
        }

        table inet filter {
          chain forward {
            type filter hook forward priority 0; policy drop;

            # Allow return connections
            ct state established,related accept;

            # Allow NAT forwarding
            iifname ${hostVars.ifLan1} oifname ${hostVars.ifInternet} accept;
            iifname ${hostVars.ifLan2} oifname ${hostVars.ifInternet} accept;

            # Http, Https
            ip daddr ${hostVars.ipNginx} tcp dport 80 accept;
            ip daddr ${hostVars.ipNginx} tcp dport 443 accept;

            # Server2
            ip daddr ${hostVars.ipServer2} tcp dport 51250 accept;
            ip daddr ${hostVars.ipServer2} udp dport 51250 accept;

            # Netbird Relay
            ip daddr ${hostVars.ipNginx} udp dport 33080 accept;

            # Route lan2 request to lan1
            iifname ${hostVars.ifLan2} oifname "${hostVars.ifLan1}" ip daddr ${hostVars.ipLan1Cidr} accept;

            # Vpnproxy-1 Sockd
            iifname ${hostVars.ifLan1} ip daddr ${hostVars.ipVpnProxy1} tcp dport 1080 accept;

            # Forgejo SSH
            iifname ${hostVars.ifLan1} ip daddr ${hostVars.ipDesktop1} tcp dport 30059 accept;
          }

          # Allow all packets sent by the firewall
          chain output {
            type filter hook output priority 0; policy accept;
          }

          # Incoming packets rules
          chain input {
            type filter hook input priority 0; policy drop;

            # Allow return connections
            ct state established,related accept;

            # Allow localhost
            iif lo accept;

            # dhcp
            iifname != { ${hostVars.ifInternet} } udp dport 67 accept
            iifname != { ${hostVars.ifInternet} } udp dport 68 accept

            # dns
            iifname != { ${hostVars.ifInternet} } udp dport 53 accept
            iifname != { ${hostVars.ifInternet} } tcp dport 53 accept

            # icmp echo
            icmp type echo-request accept

            # Drop bad packets
            # ct status invalid drop;

            # Allow SSH
            iifname != { ${hostVars.ifInternet} } tcp dport 22 accept; # Do not remove

            # Adguard Home
            iifname != { ${hostVars.ifInternet} } tcp dport 3000 accept;

            # Netdata
            iifname != { ${hostVars.ifInternet} } tcp dport 19999 accept;

            # Sockd
            iifname != { ${hostVars.ifInternet} } tcp dport 1080 accept;

            # Squid
            iifname != { ${hostVars.ifInternet} } tcp dport 3128 accept;
          }
        }

        table inet nat {
          chain prerouting {
            type nat hook prerouting priority 0; policy accept;

            # !! Note: Need to add forward accept rules too !!

            # Redirect HTTP, HTTPS
            iifname "${hostVars.ifInternet}" tcp dport { 80, 443 } dnat ip to ${hostVars.ipNginx};
            iifname "${hostVars.ifLan1}" tcp dport { 80, 443 } dnat ip to ${hostVars.ipNginx};

            # Netbird Relay
            iifname "${hostVars.ifInternet}" udp dport { 33080 } dnat ip to ${hostVars.ipNginx};

            # Server 2
            iifname "${hostVars.ifInternet}" tcp dport 51250 dnat ip to ${hostVars.ipServer2};
            iifname "${hostVars.ifInternet}" udp dport 51250 dnat ip to ${hostVars.ipServer2};

            # Vpnproxy-1
            iifname ${hostVars.ifLan1} tcp dport 1085 dnat ip to ${hostVars.ipVpnProxy1}:1080;

            # Forgejo
            iifname ${hostVars.ifLan1} tcp dport 30059 dnat ip to ${hostVars.ipDesktop1};
          }

          chain postrouting {
            type nat hook postrouting priority 100; policy accept;

            oifname ${hostVars.ifInternet} masquerade;
          }
        }
      '';
    };
  };

  # Traffic shaping with fireqos
  services.fireqos = {
    enable = true;
    config = ''
      FIREQOS_CONNMARK_RESTORE="act_connmark"

      DEVICE="${hostVars.ifInternet}"
      LINKTYPE=""
      INPUT_SPEED="$((${hostVars.inetIngressSpeedInMB} * 1000 * 97 / 100))kbit"
      OUTPUT_SPEED="$((${hostVars.inetEngressSeeedInMB} * 1000 * 97 / 100))kbit"

      interface $DEVICE world bidirectional $LINKTYPE input rate $INPUT_SPEED output rate $OUTPUT_SPEED qdisc cake
        class interactive prio 2 # input commit 20% output commit 10%
          server icmp
          server dns
          client dns

        class synacks prio 5
          match tcp syn
          match tcp ack

        class default prio 6

        class servers input commit 10% max 85% output commit 10% max 85% prio 7
          match rawmark 5
          match rawmark 6
          match rawmark 7
          match rawmark 8
    '';
  };
}
