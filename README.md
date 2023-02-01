# AVD Cheatsheet

Common things you need to set for AVD.

## Common Inventory

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