/**
  see:
    - https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_vm
 */
module "cacti" {
  source  = "lucidsolns/flatcar-vm/proxmox"
  version = "1.0.10"

  vm_id          = var.vm_id
  vm_name        = var.vm_name
  vm_description = "Cacti running on Flatcar Linux"
  node_name      = var.target_node
  tags = [
    "cacti",
    "flatcar",
    "ops",
  ]

  cpu = {
    cores = 2
    // Broadwell Xeon-D
    // see: https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_vm#type-11
    type  = "x86-64-v3"
  }
  memory = {
    dedicated = 1500
    floating  = 512
  }
  bridge  = var.bridge
  vlan_id = var.vlan_id

  butane_conf         = "${path.module}/cyan.bu.tftpl"
  butane_snippet_path = "${path.module}/config"
  butane_variables = {
    DB_ROOT_PASSWORD  = random_password.db_root_password.result
    DB_CACTI_PASSWORD = random_password.db_cacti_password.result
  }

  storage_images = var.storage_images
  storage_root   = var.storage_root
  storage_path_mapping = {
    "${var.storage_root}" = "/droplet/vmroot"
  }

  persistent_disks = [
    {
      datastore_id = var.storage_data
      size         = 2
      iothread     = true
      discard      = "on"
      backup       = true
    }
  ]
}


/*
  Generate a random password to be used for the 'owncloud' user for the db server
*/
resource "random_password" "db_cacti_password" {
  length  = 32    # number of characters
  special = false # include special chars
}

/*
  Generate a random password to be used for the 'root' user for the db server
*/
resource "random_password" "db_root_password" {
  length  = 32    # number of characters
  special = false # include special chars
}

/*
  This VM terraform was used to develop the Flatcar Linux module. As part of moving to the
  final published module, the persistent disks with the data/database need to be kept.

  see:
    - https://developer.hashicorp.com/terraform/language/moved
*/
moved {
  from = proxmox_virtual_environment_vm.data_disk
  to   = module.cacti.module.vm[0].proxmox_virtual_environment_vm.persistent_disk[0]
}