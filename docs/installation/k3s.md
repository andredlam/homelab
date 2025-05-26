#### Setup k3s

##### Requirements

- ansible > 2.11
- install collections (see steps below)
- servers and agents must have passwordless  

```shell
# to install the requirements
$ cd ansible
$  ansible-galaxy collection install -r ./requirements/k3s/requirements.yaml

# copy key to target server(s) and agents
$ ssh-copy-id -i id_ed25519.pub andre@<ansible-ip>

# ping all servers listed in inventory  (-m is module)
$ ansible all --key-file ~/.ssh/id_ed25519 -i inventory -m ping

# run "sudo apt update" on all servers 
$ ansible all -m apt -a update_cache=true --become --ask-become-pass

# to run
$ ansible-playbook --ask-become-pass playbooks/kubernetes.yaml -i environments/staging.ini
```
<br />


References:
1. [Ansible playbooks](https://github.com/techno-tim/k3s-ansible)
