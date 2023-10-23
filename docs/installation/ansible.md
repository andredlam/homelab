#### Setup ansible

```shell
# generate ssh key (-C for comment)
$ ssh-keygen -t ed25519 -C ansible   (or with -f .ssh/ansible)

# copy key to target server(s)
$ ssh-copy-id -i id_ed25519.pub andre@10.0.0.241

# install ansible
$ apt install ansible

# ping all servers listed in inventory  (-m is module)
$ ansible all --key-file ~/.ssh/id_ed25519 -i inventory -m ping

# run "sudo apt update" on all servers 
$ ansible all -m apt -a update_cache=true --become --ask-become-pass


# to run
$ ansible-playbook --ask-become-pass playbooks/kubernetes.yaml -i environments/staging.ini
```

