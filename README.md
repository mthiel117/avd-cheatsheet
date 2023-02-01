# AVD Cheatsheet

Common things you need to set for AVD arte shown below.  Also, there are 2 example inventories (L2LS Campus and L3LS EVPN-VXLAN) with full data model (group_vars) included.

## Install AVD

``` shell
# Latest version
ansible-galaxy collection install arista.avd

# Specific version
ansible-galaxy collection install arista.avd:==3.6.0

# Development Branch
ansible-galaxy collection install git+https://github.com/aristanetworks/ansible-avd.git#/ansible_collections/arista/avd/,devel
```

### Install Python Requirements

``` shell
export ARISTA_AVD_DIR=$(ansible-galaxy collection list arista.avd --format yaml | head -1 | cut -d: -f1)
pip3 install -r ${ARISTA_AVD_DIR}/arista/avd/requirements.txt
```

## Typical ansible.cfg

``` shell
[defaults]
inventory=inventory.yml
deprecation_warnings = False
host_key_checking = False
gathering = explicit
retry_files_enabled = False
jinja2_extensions =  jinja2.ext.loopcontrols,jinja2.ext.do,jinja2.ext.i18n
```

## Common inventory.yml

``` yaml
---
DC1:
  children:
    CVP:
      hosts:
        cvp:
    DC1_FABRIC:
      children:
        DC1_SPINES:
          hosts:
            spine1:
            spine2:
        DC1_LEAFS:
          hosts:
            leaf1:
            leaf2:
            leaf3:
            leaf4:
    DC1_FABRIC_SERVICES:
      children:
        DC1_SPINES:
        DC1_LEAFS:
    DC1_FABRIC_PORTS:
      children:
        DC1_SPINES:
        DC1_LEAFS:
```

## Connecting to your switches

Ansible variables needed to connect to your switches should you intend to deploy configs via eAPI.  Typically apply these to an ansible group that applies to all switches.

First you need to enable API access on the switches.

``` shell
management api http-commands
   no shutdown
   !
   vrf MGMT
      no shutdown
!
```

Then set these variables.

``` yaml
ansible_connection: ansible.netcommon.httpapi
# Specifies that we are indeed using Arista EOS
ansible_network_os: arista.eos.eos
# This user/password must exist on the switches to enable Ansible access
ansible_user: admin
ansible_password: admin
# User escalation (to enter enable mode)
ansible_become: true
ansible_become_method: enable
# Use SSL (HTTPS)
ansible_httpapi_use_ssl: true
# Do not try to validate certs
ansible_httpapi_validate_certs: false
```

## Connecting to CVP On-Prem

``` yaml
# Set these variables for the CVP host in your inventory.yml

ansible_httpapi_host: 10.83.28.164
ansible_host: 10.83.28.164
ansible_user: ansible
ansible_password: ansible
ansible_connection: httpapi
ansible_httpapi_use_ssl: True
ansible_httpapi_validate_certs: False
ansible_network_os: eos
ansible_httpapi_port: 443
# Configuration to get Virtual Env information
ansible_python_interpreter: $(which python3)
```

## Connecting to CVaaS

``` yaml
# Set these variables for the CVaaS host in your inventory.yml

ansible_host: www.arista.io
ansible_user: cvaas
# CVaaS Service Token - Good until 10/08/2023
ansible_ssh_pass: eyJhbGciOiJFUzI1NiIsInR5cCI6IkpXVCJ9eyJkaWQiOjcwODkzNDMxODEzNjM1Nzc3NTksImRzbiI6IkFWRCIsImRzdCI6ImFjY291bnQiLCJleHAiOjE2OTY5MzkxOTksImlhdCI6MTY2NTQwNjQyOCwic2lkIjoiZWUxdsKJHYFWEFHJIEQRWYHVP98YDSVHAFYkwDMyMS1aQWxIX01zc0hMMVFPODdPTkdTemlGWDRaY0d3YmZMR1JUTnkzOFhNIn0dF2Mj_4NXBFDyG-MeKdSwhcZ7rZm_n8gmWE72lPIDA-TVwI17EpiX5_yozmLl7aOc63YG4JRCZ4VHDj_pK5mSQ
ansible_connection: httpapi
ansible_network_os: eos
```

## Build Playbook

``` yaml
---
- name: Build Switch configuration
  hosts: DC1_FABRIC
  gather_facts: false
  tasks:

    - name: Generate Structured Variables per Device
      import_role:
        name: arista.avd.eos_designs

    - name: Generate Intended Config and Documentation
      import_role:
        name: arista.avd.eos_cli_config_gen
```

## Deploy Playbook

``` yaml
---
- name: Deploy Switch configuration
  hosts: DC1_FABRIC
  gather_facts: false
  tasks:

    - name: Deploy Configuration to Device
      import_role:
         name: arista.avd.eos_config_deploy_eapi
```

## CVP/CVaaS Deploy Playbook

``` yaml
---
- name: Deploying Changes via CVP
  hosts: cvp
  connection: local
  gather_facts: false
  tasks:
    - name: run CVP provisioning
      import_role:
          name: arista.avd.eos_config_deploy_cvp
      vars:
        container_root: 'ATD_FABRIC'
        configlets_prefix: 'AVD'
        state: present
        device_filter: 's1'
        # execute_tasks: true
```

## TerminAttr Data Model

``` yaml
# TerminAttr
daemon_terminattr:
  # Address of the gRPC server on CloudVision
  # TCP 9910 is used on on-prem
  # TCP 443 is used on CV as a Service
  cvaddrs: # For single cluster
    - 192.168.0.5:9910
  # Authentication scheme used to connect to CloudVision
  # Deprecated Key Method, use Token
  # cvauth:
  #   method: key
  #   key: atd-lab
  cvauth:
    method: token
    token_file: "/tmp/token"
  # Exclude paths from Sysdb on the ingest side
  ingestexclude: /Sysdb/cell/1/agent,/Sysdb/cell/2/agent
  # Exclude paths from the shared memory table
  smashexcludes: ale,flexCounter,hardware,kni,pulse,strata
  # Disable AAA authorization and accounting. When setting this flag, all commands pushed
  # from CloudVision are applied directly to the CLI without authorization
  disable_aaa: true
```

## Port Profile

Define Port Profiles to be used by Network Ports.

``` yaml
port_profiles:
  PP-IDF1:
    mode: "trunk phone"
    spanning_tree_portfast: edge
    spanning_tree_bpduguard: enabled
    dot1x:
      port_control: force-authorized # For Lab without RADIUS NAC server
      reauthentication: true
      pae:
        mode: authenticator
      host_mode:
        mode: multi-host
        multi_host_authenticated: true
      mac_based_authentication:
        enabled: true
      authentication_failure:
        action: allow
        allow_vlan: 100
      timeout:
        reauth_period: server
        tx_period: 3
      reauthorization_request_limit: 3

  PP-IDF2:
    mode: "access"
    vlans: 20
    spanning_tree_portfast: edge
    spanning_tree_bpduguard: enabled
```

## Network Ports

Define what switches and ports use a Port Profile.  Regex matching on the switches is possible.
Switch ports expansion examples can be found [here](https://avd.sh/en/stable/plugins/index.html#range_expand-filter).

``` yaml
network_ports:

  ################################################################
  # IDF1 - 802.1x Enabled
  ################################################################

  - switches:
      - LEAF[12] # regex match LEAF1A & LEAF1B
    switch_ports:
      - Ethernet1-48
    description: IDF1 Standard Port
    profile: PP-IDF1
    native_vlan: 10
    structured_config:
      phone:
        trunk: untagged
        vlan: 15

  ################################################################
  # IDF2 - Standard Access Ports
  ################################################################

  - switches:
      - LEAF[34]
    switch_ports:
      - Ethernet1-48
    description: IDF2 Standard Port
    profile: PP-IDF2
```

## Makefile

Sample Makefile with entries to run playbooks

``` shell
.PHONY: help
help: ## Display help message
	@grep -E '^[0-9a-zA-Z_-]+\.*[0-9a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: campus
campus: ## Build Campus Configs
	ansible-playbook -i inventories/l2ls-campus/inventory.yml playbooks/campus.yml

.PHONY: evpn
evpn: ## Build Campus Configs
	ansible-playbook -i inventories/l3ls-evpn-vxlan/inventory.yml playbooks/evpn.yml
```

Usage:

``` shell
make campus
make evpn
```
