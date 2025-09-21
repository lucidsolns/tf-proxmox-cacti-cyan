# [A Cacti instance running on Proxmox](https://github.com/lucidsolns/tf-proxmox-cacti-cyan/blob/main/README.md)

This repository provisions a Cacti instance:
  - using Terraform
  - a Proxmox virtual machine
  - running Flatcar Linux
  - with an ignition configuration to bootstrap the machine
  - with a docker-compose file to run
    - a postgres database container instance
    - cacti container image

This is a small standalone instance intended to have limited scalability for
monitoring local network/machine instances.

**Notes:** 
 - Manual configuration of the Cacti instance is not described here (the initial username/password is admin/admin)
 - Terraform (`terraform.tfstate`) state is stored locally
 - An external http reverse proxy provides TLS offload/certificates 

# Terraform Notes

This module uses the BPG/Proxmox provider in 
a [flatcar module](https://github.com/lucidsolns/terraform-proxmox-flatcar-vm). 
Previously these terraform scripts have been using the
[module](https://github.com/lucidsolns/terraform-flatcar-ignition-proxmox).

# Benefits

Provisioning this virtual machine with `bpg/proxmox` over `Telmate/proxmox` means:

- no additional scripts are needed that hook into the VM lifecycle
- persistent disk images can be created (perhaps this could also be done with Telmate/proxmox)
- no template VM is required, the Flatcar Linux image is used directly
- the setup for disks is cleaner and simpler
- with both Proxmox, Flatcar Linux and bpg/Proxmox having first class support for virtiofs, this
  becomes a viable option for some lower performance filesystem

# Known issues

1. The terraform state is stored locally. This makes provisioning from a build pipeline
   way more difficult.
1. There is no way to map a storage identifier to a full path. This is only applicable
   to file storage types that have a local path (e.g. directory). As a workaround this mapping
   from an identifier of the form 'type:type/file_name' is done manually in terraform.
   The bpg/Proxmox provider code does have a function that gets the path from the storage
   provider, so this functionality could be implemented (see `proxmox/storage/storage.go:GetDatastore()`).
2. The Proxmox server requires root access to set the KVM/Qemu args parameter.
3. There doesn't seem to be a way to provision the Flatcar provided UEFI vars and code images.
4. The idea of having a second VM that never changes to hold a disk is a novel idea, but it
   is a workaround that needs a real/good solution.

# Changing the MariaDB password

From the FLatcar command line, get a shell inside the database container and run mariadb 
command line as the root user. Enter the existing root password:
```shell
docker exec -it db bash
mariadb -u root -p
```

Determine which passwords have been configured and which will be changed:
```mysql
SELECT user, host, plugin FROM mysql.user;
```

For each user being changed:
```mysql
ALTER USER 'myuser'@'localhost' IDENTIFIED BY 'MyNewPassword';
FLUSH PRIVILEGES;
```

example:
```mysql
ALTER USER 'root'@'localhost' IDENTIFIED BY 'MyNewPassword';
ALTER USER 'root'@'%' IDENTIFIED BY 'MyNewPassword';
ALTER USER 'cacti'@'%' IDENTIFIED BY 'MyNewPassword';
```

The password used by the Cacti container is stored in `/cacti/include/config.php` in
the container, or `/srv/cacti-data/include/config.php` in the Flatcar docker host.

# Links

 - https://github.com/lucidsolns/terraform-proxmox-flatcar-vm
 - https://registry.terraform.io/providers/bpg/proxmox/latest
 - https://www.cacti.net/ 
 - https://developer.hashicorp.com/terraform/install
 - https://github.com/flatcar/Flatcar
 - https://hub.docker.com/r/smcline06/cacti
 - https://github.com/flatcar/scripts/pull/2825
 - https://github.com/flatcar/flatcar-terraform

# Appendices

## Example credentials.auto.tfvars

```properties
pm_api_url = "https://proxmox.example.com:8006/api2/json"
pm_user     = "root@pam"
pm_password = "supersecretpassword"
target_node = "node-name"
```