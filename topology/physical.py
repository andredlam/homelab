from diagrams import Diagram
from diagrams.azure.network import Firewall
from diagrams.onprem.network import Internet
from diagrams.onprem.compute import Server
from diagrams.generic.network import Router
from diagrams.generic.network import Switch
from diagrams.generic.storage import Storage

with Diagram("physical", show=True):
    inet = Internet("Internet")
    fw = Firewall("Firewall")
    s1 = Server("Mini-1")
    s2 = Server("Mini-2")
    s3 = Server("Mini-3")

    # Additional standalone servers
    switch = Switch("Switch")
    s4 = Server("DELL-1")
    s5 = Server("DELL-2")
    s6 = Server("DELL-3")
    storage = Storage("Storage")

    inet >> fw >> [s1, s2, s3]
    [s1, s2, s3] >> switch
    switch >> [s4, s5, s6]
    [s4, s5, s6] >> storage
