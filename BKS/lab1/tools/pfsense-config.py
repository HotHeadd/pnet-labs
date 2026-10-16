"""Конфиг pfSense HQ-FW-1 / HQ-FW-2: прозрачный мост (L2) без фильтрации + интерфейс управления.

МЭ встают «в разрыв» линков HQ-EDGE–ядро (и HQ-EDGE–DMZ на HQ-FW-2) и пропускают всё.
Адресация, маршрутизация и NAT стенда не меняются. Политики МЭ — в следующих ЛР.

Использование: python pfsense-config.py <исходный config.xml> <узел> <выходной config.xml>
Исходный config.xml — выгрузка с самого pfSense (Diagnostics > Backup & Restore).
"""
import sys
import xml.etree.ElementTree as ET

MGMT_MASK = "24"
MGMT_GW = None  # шлюз сети управления не нужен

NODES = {
    "HQ-FW-1": dict(
        mgmt="192.168.226.20",
        ifaces={  # имя в конфиге: (устройство, описание)
            "wan": ("vtnet0", "TO_HQ_EDGE"),
            "opt1": ("vtnet1", "TO_HQ_CORE1"),
        },
        bridges=[("wan,opt1", "HQ-EDGE e0/1 - HQ-CORE-1 e0/0")],
    ),
    "HQ-FW-2": dict(
        mgmt="192.168.226.21",
        ifaces={
            "wan": ("vtnet0", "TO_HQ_EDGE"),
            "opt1": ("vtnet1", "TO_HQ_CORE2"),
            "opt2": ("vtnet2", "DMZ_EDGE_SIDE"),
            "opt3": ("vtnet3", "DMZ_SWITCH_SIDE"),
        },
        bridges=[("wan,opt1", "HQ-EDGE e0/2 - HQ-CORE-2 e0/0"),
                 ("opt2,opt3", "HQ-EDGE e0/3 - HQ-DMZ e0/0 (DMZ)")],
    ),
}


def sub(parent, tag, text=""):
    el = ET.SubElement(parent, tag)
    el.text = text
    return el


def reset(root, tag):
    """Удалить секцию и создать пустую заново."""
    for el in root.findall(tag):
        root.remove(el)
    return sub(root, tag)


def main():
    src, name, dst = sys.argv[1:4]
    n = NODES[name]
    tree = ET.parse(src)
    root = tree.getroot()

    system = root.find("system")
    system.find("hostname").text = name
    system.find("domain").text = "hq.local"
    for tag in ("disablefilter", "disablechecksumoffloading",
                "disablesegmentationoffloading", "disablelargereceiveoffloading"):
        if system.find(tag) is None:
            sub(system, tag, "enabled" if tag == "disablefilter" else "")
    for ts in system.findall("timeservers"):
        ts.text = "10.1.55.10"

    # Интерфейсы: члены мостов без IP, LAN — управление
    ifs = reset(root, "interfaces")
    lan = sub(ifs, "lan")
    sub(lan, "enable"); sub(lan, "if", "vtnet4"); sub(lan, "descr", "MGMT")
    sub(lan, "ipaddr", n["mgmt"]); sub(lan, "subnet", MGMT_MASK)
    for key, (dev, descr) in n["ifaces"].items():
        el = sub(ifs, key)
        sub(el, "enable"); sub(el, "if", dev); sub(el, "descr", descr)

    br = reset(root, "bridges")
    for i, (members, descr) in enumerate(n["bridges"]):
        b = sub(br, "bridged")
        sub(b, "members", members); sub(b, "descr", descr); sub(b, "bridgeif", f"bridge{i}")

    # Без DHCP-сервера, DNS Resolver и шлюзов по умолчанию с WAN
    for tag in ("dhcpd", "dhcpdv6", "gateways"):
        for el in root.findall(tag):
            root.remove(el)
    unbound = root.find("unbound")
    if unbound is not None and unbound.find("enable") is not None:
        unbound.remove(unbound.find("enable"))

    tree.write(dst, encoding="utf-8", xml_declaration=True)


if __name__ == "__main__":
    main()
