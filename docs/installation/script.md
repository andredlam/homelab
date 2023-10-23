**Prepare server**
After a fresh installation of ubuntu 22.04, from terminal

```sh
    # Generate 30 characters random password (can make it longer if needed)
    $ openssl rand 30 | openssl base64 -A
    6GDa4S+Ao/k6uRJCNdCXworQpUakYTHcZfggV4F4
```

Run installation script

```sh
   # ubuntu 22.04
   $ ./installation/install.sh
```

Manual edit

```sh
    # edit redis config
    $ vi /etc/redis/redis.conf
    requirepass 6GDa4S+Ao/k6uRJCNdCXworQpUakYTHcZfggV4F4

    $ sudo systemctl restart redis.service
```