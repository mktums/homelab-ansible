hw:
    ansible-playbook playbooks/collect_hw.yml

tags TAGS:
    ansible-playbook playbooks/site.yml --tags {{TAGS}}
