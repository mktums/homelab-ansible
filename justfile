deploy:
    ansible-playbook --vault-password-file .vault_pass -e @vault/secrets.yml playbooks/site.yml

hw:
    ansible-playbook --vault-password-file .vault_pass -e @vault/secrets.yml playbooks/collect_hw.yml

router:
    ansible-playbook --vault-password-file .vault_pass -e @vault/secrets.yml playbooks/router.yml

servers:
    ansible-playbook --vault-password-file .vault_pass -e @vault/secrets.yml playbooks/servers.yml

tags TAGS:
    ansible-playbook --vault-password-file .vault_pass -e @vault/secrets.yml playbooks/site.yml --tags {{TAGS}}
