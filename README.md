# AVD Cheatsheet

Common things you need to set for AVD.

## Common Inventory

``` yaml
---
CAMPUS:
  children:
    CVP:
      hosts:
        cvp:
    CAMPUS_FABRIC:
      children:
        CAMPUS_SPINES:
          hosts:
            spine1:
            spine2:
        CAMPUS_LEAFS:
          hosts:
            leaf1:
            leaf2:
            leaf3:
            leaf4:
    CAMPUS_FABRIC_SERVICES:
      children:
        CAMPUS_SPINES:
        CAMPUS_LEAFS:
    CAMPUS_FABRIC_PORTS:
      children:
        CAMPUS_SPINES:
        CAMPUS_LEAFS:
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
  hosts: CAMPUS_FABRIC
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
  hosts: ATD_FABRIC
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