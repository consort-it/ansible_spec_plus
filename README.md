# ansible_spec_plus

Tests Ansible roles, hosts and playbooks separately with Serverspec. Provides test coverage. Supports local and remote test execution.

This is a Ruby gem that uses the [Ansible Config Parser for Serverspec](https://github.com/volanja/ansible_spec) connector and
extends it to be able to run tests for roles, hosts or playbooks separately.

# Features

- Supports all features of [ansible_spec](https://github.com/volanja/ansible_spec)
- Supports listing of available tests
- Supports separate test execution of role tests
- Supports separate test execution of host tests
- Supports separate test execution of playbook tests (playbook tests combine role and hosts tests)
- Supports resource code/test coverage
- Supports remote (default) and local test execution (on a Vagrant box for example) by a command switch

# Installation

```
$ gem install ansible_spec_plus
```

# Usage

## Create necessary files

```
$ asp-init
    create  spec
    create  spec/spec_helper.rb
    create  .ansiblespec
    create  .rspec
```

## [Optional] `site.yml`

This files describes the master playbook and includes all your custom
playbooks. Ansible Spec plus relies on all entries when it comes to
playbooks. If you ever create a playbook, make sure to add it into `site.yml`,
too.

```site.yml
- include: demo.yml
- include: another-playbook.yml
```

## [Optional] `.ansiblespec`

By default, `site.yml` will be used as the playbook and `hosts` as the
inventory file. You can either follow these conventions or you can
customize the playbook and inventory using an `.ansiblespec` file.

```.ansiblespec
---
-
  playbook: site.yml
  inventory: hosts
  hash_behaviour: merge
```

## [Optional] `.rspec`

Test coverage calculation rested on RSpec's JSON report.

```.rspec
--color
--format documentation
--format json --out report.json
```

## Inventory

All inventory files from [ansible_spec](https://github.com/volanja/ansible_spec) are supported
as well as Vagrant-style inventory files like this:

```hosts
# Generated by Vagrant

dev ansible_ssh_host=127.0.0.1 ansible_ssh_port=2222 ansible_ssh_private_key_file=private_key ansible_ssh_user=vagrant
```

These Vagrant-style inventories will be created by Vagrant's VAI plugin. No need to add this to
version control. Install the VAI plugin with `vagrant plugin install vai` and add this section
to your Vagrantfile:

```Vagrantfile
config.vm.provision :vai do |ansible|
  ansible.inventory_dir = './'
  ansible.inventory_filename = 'hosts'
end
```

## Writing tests

You can write tests for roles and/or hosts. Create a `*_spec.rb` file at the proper place (see below).
Require your spec_helper to include all needed logic and start writing your specs. Use all resource types
described at the [Serverspec documentation](http://serverspec.org/resource_types.html).

## Running tests

#### Role tests

Role tests can be found under `roles/<name of your role>/spec/*_spec.rb`. Execute tests by simply typing

```
asp rolespec <name of your role>
```

or - for local test execution on a Vagrant box -

```
asp rolespec <name of your role> -l
```

#### Host tests

Host tests can be found under `spec/<name of your host>/*_spec.rb`. Execute tests by simply typing

```
asp hostspec <name of your host>
```

or - for local test execution on a Vagrant box -

```
asp hostspec <name of your host> -l
```

#### Playbook tests

Host tests combine role and host tests for a given playbook. Execute tests by simply typing

```
asp playbookspec <name of your playbook>
```

or - for local test execution on a Vagrant box -

```
asp playbookspec <name of your playbook> -l
```

## Example

Please see [ansible-example](https://github.com/consort-it/ansible-example) for a full working example.

```
├── Gemfile
├── Gemfile.lock
├── README.md
├── Vagrantfile
├── ansible.cfg
├── demo.yml
├── hosts
├── report.json
├── roles
│   ├── common
│   │   ├── defaults
│   │   │   └── main.yml
│   │   ├── spec
│   │   │   └── main_spec.rb
│   │   ├── tasks
│   │   │   └── main.yml
│   │   └── templates
│   │       └── profile
│   ├── demo
│   │   ├── spec
│   │   │   └── main_spec.rb
│   │   └── tasks
│   │       └── main.yml
│   └── docker
│       ├── defaults
│       │   └── main.yml
│       ├── spec
│       │   └── main_spec.rb
│       ├── tasks
│       │   └── main.yml
│       └── templates
│           ├── config.json
│           └── docker.cfg
├── scripts
│   └── bootstrap_ansible.sh
├── site.yml
└── spec
    ├── demo
    │   └── demo_spec.rb
    └── spec_helper.rb
```

1. Create the test code that verifies our future Ansible implementation:

```roles/docker/spec/common_spec.rb
require 'spec_helper'

describe package('python-pip') do
  it { should be_installed.by('apt') }
end
```

2. Run the test and see it fail:

`asp rolespec docker`

```
Package "docker-engine"
  should be installed by "apt"

Package "python-pip"
  should be installed by "apt" (FAILED - 1)

Failures:

  1) Package "python-pip" should be installed by "apt"
     On host `127.0.0.1'
     Failure/Error: it { should be_installed.by('apt') }
       expected Package "python-pip" to be installed by "apt"
       sudo -p 'Password: ' /bin/sh -c dpkg-query\ -f\ \'\$\{Status\}\'\ -W\ python-pip\ \|\ grep\ -E\ \'\^\(install\|hold\)\ ok\ installed\$\'

     # ./roles/docker/spec/main_spec.rb:8:in `block (2 levels) in <top (required)>'

Finished in 0.56807 seconds (files took 1.02 seconds to load)
2 examples, 1 failure

Failed examples:

rspec ./roles/docker/spec/main_spec.rb:8 # Package "python-pip" should be installed by "apt"
```

3. Implement the Ansible feature and provision your system:

```roles/docker/tasks/main.yml
- name: Debian python-pip is present
  apt:
    name: python-pip
    state: present
    force: yes
```

`vagrant provision demo`

4. Run the test again and see it pass:

`asp rolespec docker`

```
Package "docker-engine"
  should be installed by "apt"

Package "python-pip"
  should be installed by "apt"

Finished in 0.70224 seconds (files took 1.24 seconds to load)
2 examples, 0 failures

W, [2017-04-04T18:57:08.650883 #70141396384260]  WARN -- : Unknown resource: {"name"=>"Debian add Docker repository and update apt cache", "apt_repository"=>{"repo"=>"deb https://apt.dockerproject.org/repo ubuntu-trusty main", "update_cache"=>true, "state"=>"present"}, "roles"=>[]}
W, [2017-04-04T18:57:08.651194 #70141396384260]  WARN -- : Unknown resource: {"name"=>"Debian Daemon is reloaded", "command"=>"systemctl daemon-reload", "when"=>"copy_result|changed and is_systemd is defined", "roles"=>[]}
W, [2017-04-04T18:57:08.651412 #70141396384260]  WARN -- : Unknown resource: {"name"=>"vagrant user is added to the docker group", "user"=>{"name"=>"vagrant", "group"=>"docker"}, "register"=>"user_result", "roles"=>[]}
Total resources: 9
Touched resources: 2
Resource coverage: 22%

Uncovered resources:
- Package "docker-py"
- File "/etc/default/docker"
- Service "docker"
- File "/root/.docker"
- File "/root/.docker/config.json"
- File "/home/vagrant/.docker"
- File "/home/vagrant/.docker/config.json"
```

# Contributing

* Fork it
* Write awesome code
* Test your awesome code (`bundle exec guard` and `rspec` are your friends)
* Create your feature branch (`git checkout -b my-new-feature`)
* Commit your changes (`git commit -am 'Add some feature'`)
* Push to the branch (`git push origin my-new-feature`)
* Create new Pull Request at https://github.com/consort-it/ansible_spec_plus
* Contact us
