ssh -D 9000 <user>@<server-ip>
for p in 5000 5001 5002 5003; do ssh -f -N -L localhost:$p:<remote-ip>:$p <user>@<gateway-ip>; done