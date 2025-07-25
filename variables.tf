/*
 * The API requires credentials. Use an API key (c.f. username/password), by going to the
 * web UI 'Datacenter' -> 'Permissions' -> 'API Tokens' and create a new set of credentials.
 *
*/
variable "pm_api_url" {
  description = "The proxmox api endpoint"
  default     = "https://proxmox:8006/api2/json"
}

//
// see
//  - https://thenewstack.io/automate-k3s-cluster-installation-on-flatcar-container-linux/
//
variable "target_node" {
  default = "proxmox"
}


variable "pm_user" {
  description = "A username for password based authentication of the Proxmox API"
  type        = string
  default     = "root@pam"
}

variable "pm_password" {
  description = "A password for password based authentication of the Proxmox API"
  type        = string
  sensitive   = true
  default     = ""
}

variable "ssh_username" {
  description = "The SSH username used when performing commands that require SSH access to Proxmox"
  default     = "root"
  type        = string

}
variable "bridge" {
  default = "vmbr0"
}

variable "vlan_id" {
  default = "111"
}
variable vm_id {
  description = "The Proxmox integer id of the VM"
  default = 160
}

variable vm_name { default = "cyan.lucidsolutions.co.nz" }


variable "storage_images" { default = "vmroot" }
variable "storage_root" { default = "vmroot" }
variable "storage_data" { default = "vmdata" }
variable storage_path_mapping {
  description = "Mapping of storage name to a local path"
  type = map(string)
  default = {
    "vmroot" = "/droplet/vmroot"
  }
}

variable "vm_count" {
  default = 1
  type    = number
}
variable "butane_conf" { default = "cyan.bu.tftpl" }
variable butane_snippet_path { default = "config" }
variable butane_conf_snippets {
  default = []
  type = list(string)
}