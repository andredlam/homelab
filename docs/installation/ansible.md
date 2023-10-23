#### Setup ansible

##### Generate ssh key

```shell
# generate ssh key (-C for comment)
$ ssh-keygen -t ed25519 -C ansible   (or with -f .ssh/ansible)

# copy key to target server(s)
$ ssh-copy-id -i id_ed25519.pub andre@<ansible-ip>

# install ansible
$ apt install ansible

# ping all servers listed in inventory  (-m is module)
$ ansible all --key-file ~/.ssh/id_ed25519 -i inventory -m ping

# run "sudo apt update" on all servers 
$ ansible all -m apt -a update_cache=true --become --ask-become-pass

# to run
$ ansible-playbook --ask-become-pass playbooks/kubernetes.yaml -i environments/staging.ini
```
<br />

##### Directory Layout for referrence for ansible

```shell
    # https://docs.ansible.com/ansible/2.8/user_guide/playbooks_best_practices.html

    production                # inventory file for production servers
    staging                   # inventory file for staging environment

    group_vars/
        group1.yml             # here we assign variables to particular groups
        group2.yml
    host_vars/
        hostname1.yml          # here we assign variables to particular systems
        hostname2.yml

    library/                  # if any custom modules, put them here (optional)
    module_utils/             # if any custom module_utils to support modules, put them here (optional)
    filter_plugins/           # if any custom filter plugins, put them here (optional)

    site.yml                  # master playbook
    webservers.yml            # playbook for webserver tier
    dbservers.yml             # playbook for dbserver tier

    roles/
        common/               # this hierarchy represents a "role"
            tasks/            #
                main.yml      #  <-- tasks file can include smaller files if warranted
            handlers/         #
                main.yml      #  <-- handlers file
            templates/        #  <-- files for use with the template resource
                ntp.conf.j2   #  <------- templates end in .j2
            files/            #
                bar.txt       #  <-- files for use with the copy resource
                foo.sh        #  <-- script files for use with the script resource
            vars/             #
                main.yml      #  <-- variables associated with this role
            defaults/         #
                main.yml      #  <-- default lower priority variables for this role
            meta/             #
                main.yml      #  <-- role dependencies
            library/          # roles can also include custom modules
            module_utils/     # roles can also include custom module_utils
            lookup_plugins/   # or other types of plugins, like lookup in this case

        webtier/              # same kind of structure as "common" was above, done for the webtier role
        monitoring/           # ""
        fooapp/               # ""

```