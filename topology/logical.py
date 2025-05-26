from diagrams import Diagram
from diagrams.azure.network import Firewall
from diagrams.onprem.network import Internet
from diagrams.onprem.compute import Server
from diagrams.generic.network import Router
from diagrams.generic.network import Switch
from diagrams.generic.storage import Storage

with Diagram("logical", show=True):
    inet = Internet("Internet")
    fw = Firewall("Firewall")
    s1 = Server("Ubuntu-24.04")
    s2 = Server("Ubuntu-24.04")
    s3 = Server("Ubuntu-24.04")

    # Additional standalone servers
    switch = Switch("Switch")
    s4 = Server("KVM-1")
    s5 = Server("KVM-2")
    s6 = Server("KVM-3")
    storage = Storage("Storage")

    inet >> fw >> [s1, s2, s3]
    [s1, s2, s3] >> switch
    switch >> [s4, s5, s6]
    [s4, s5, s6] >> storage
