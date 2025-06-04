#ansible-playbook --ask-become-pass -i ./inventory/hosts ./playbooks/create_vms.yaml \
#    --extra-vars "user=$USER password=$PASSWORD dbpass=$DBPASS" \
#    --private-key=~/.ssh/id_rsa \
#    --limit k3s


ansible-playbook --ask-become-pass -i ./inventory/hosts ./playbooks/create_vms.yaml