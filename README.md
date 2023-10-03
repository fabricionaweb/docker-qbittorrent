Just another qBittorrent image. But compiled from the source.

---

**Needed docker arguments**

- `--cap-add=NET_ADMIN`
- `--sysctl="net.ipv4.conf.all.src_valid_mark=1"`
- `--sysctl="net.ipv6.conf.all.disable_ipv6=1"`


**Suggested setup using PostUp/PreDown hooks**

1. Set `LAN_CIDR` with docker environments eg: `10.0.0.0/20`
2. Add (or replace) PostUp and PreDown on your wg0.conf

    ```
    PostUp  = ip route add $LAN_CIDR via $(ip route show default | awk '{print $3}')
    PreDown = ip route del $LAN_CIDR
    PostUp  = iptables -I OUTPUT ! -d $LAN_CIDR ! -o %i -m mark ! --mark $(wg show %i fwmark) -m addrtype ! --dst-type LOCAL -j REJECT
    PreDown = iptables -D OUTPUT ! -d $LAN_CIDR ! -o %i -m mark ! --mark $(wg show %i fwmark) -m addrtype ! --dst-type LOCAL -j REJECT
    ```
