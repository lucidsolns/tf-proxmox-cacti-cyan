/**
  see:
    - https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_vm
 */
resource "proxmox_virtual_environment_vm" "flatcar_vm" {
  vm_id       = var.vm_id
  name        = var.vm_name
  description = "Cacti running on Flatcar Linux"
  node_name   = var.target_node

  tags = [
    "flatcar",
    "tf",
    "test"
  ]

  memory {
    dedicated = 1500
    floating  = 512
  }

  agent {
    enabled = true
  }

  stop_on_destroy = true
  on_boot         = true
  bios            = "ovmf"
  efi_disk {
    datastore_id = var.storage_root
    // import_from  = proxmox_virtual_environment_download_file.flatcar_uefi_vars.id
    type="4m"
  }
  boot_order = ["virtio0"]

  startup {
    order      = "3"
    up_delay   = "60"
    down_delay = "60"
  }
  operating_system {
    type = "l26"
  }

  cpu {
    cores = 2
    // Broadwell Xeon-D
    // see: https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_vm#type-11
    type  = "x86-64-v3"
  }
  scsi_hardware = "virtio-scsi-single"

  # Boot disk (Flatcar)
  disk {
    datastore_id = var.storage_root
    interface    = "virtio0"
    iothread     = true
    discard      = "on"
    size = 10
    import_from  = proxmox_virtual_environment_download_file.flatcar_image.id
    backup       = false
  }

  dynamic "disk" {
    for_each = { for idx, val in proxmox_virtual_environment_vm.data_disk.disk : idx => val }
    iterator = data_disk
    content {
      datastore_id      = data_disk.value["datastore_id"]
      path_in_datastore = data_disk.value["path_in_datastore"]
      file_format       = data_disk.value["file_format"]
      size = data_disk.value["size"]
      # assign from scsi1 and up
      interface         = "virtio${data_disk.key + 1}"
      iothread          = data_disk.value["iothread"]
      discard           = data_disk.value["discard"]
    }
  }

  # Network
  network_device {
    model   = "virtio"
    bridge  = var.bridge
    vlan_id = var.vlan_id
    mtu = 1 // use bridge MTU of 9k
  }

  // Directly set the KVM/Qemu firmware configuration. Don't use cloud-init, provide
  // the butane via Qemu firmware configuration as a file in a snippet.
  //
  // WARNING: This is likely to unleash a requirement to provision as a root user.
  //
  // see:
  // - https://github.com/bpg/terraform-provider-proxmox/pull/205
  kvm_arguments = "-fw_cfg name=opt/org.flatcar-linux/config,file=${module.butane_storage_map.path}"

  lifecycle {
    // see: https://developer.hashicorp.com/terraform/language/meta-arguments/lifecycle#replace_triggered_by
    replace_triggered_by = [
      proxmox_virtual_environment_file.flatcar_butane,
      proxmox_virtual_environment_vm.data_disk
    ]
  }
}

/**
    Create a VM for the purpose of holding disks that are never deleted (persistent data)

    see:
      - https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_vm#example-attached-disks

 */
resource "proxmox_virtual_environment_vm" "data_disk" {
  name = "${var.vm_name}-disks"
  description = "Persistent data disk for VM ${var.vm_id} '${var.vm_name}' - DO NOT DELETE"
  node_name   = var.target_node
  tags = ["persistent-storage"]
  vm_id = (var.vm_id * 10)+ 1000000
  started = false
  on_boot = false
  boot_order = []

  disk {
    datastore_id = var.storage_data
    interface    = "scsi0"
    size         = 2
    iothread     = true
    discard      = "on"
    backup       = true
  }

  lifecycle {
    prevent_destroy = false
  }
}


locals {
  FLATCAR_VERSION = "4230.2.1"
  FLATCAR_CHANNEL = "stable"
  FLATCAR_ARCHITECTURE = "amd64"

  // see: https://stable.release.flatcar-linux.net/amd64-usr/4230.2.1/
  FLATCAR_BASE_IMAGE_URL      = "https://${local.FLATCAR_CHANNEL}.release.flatcar-linux.net/${local.FLATCAR_ARCHITECTURE}-usr/${local.FLATCAR_VERSION}"
  FLATCAR_OS_IMAGE_URL        = "${local.FLATCAR_BASE_IMAGE_URL}/flatcar_production_qemu_uefi_image.img"
  FLATCAR_UEFI_VARS_IMAGE_URL = "${local.FLATCAR_BASE_IMAGE_URL}/flatcar_production_qemu_uefi_efi_vars.qcow2"
  FLATCAR_UEFI_CODE_IMAGE_URL = "${local.FLATCAR_BASE_IMAGE_URL}/flatcar_production_qemu_uefi_secure_efi_code.qcow2"
  FLATCAR_BASE_FILENAME       = "flatcar-${local.FLATCAR_ARCHITECTURE}-${local.FLATCAR_CHANNEL}-${local.FLATCAR_VERSION}"
}

/**
  Download the specific Flatcar Linux QEMU EFI images to the local machine. This is
  a one off operation that takes a few minutes.

  Note: Although the doc's indicate, that `.bz2` decompression is supported, this is not
  the case at the time of writing (July 2025). The main larger image doesn't compress
  much, so getting compressed images is of limited value.

  WARNING: Importing Disks is not enabled by default in new Proxmox installations. You
  need to enable them in the 'Datacenter>Storage' section of the proxmox interface
  before first using this resource with content_type = "import".

  To get this to 'work', manually edit `/etc/pve/storage.cfg` and add 'import' to the
  `content` attribute for the filesystem type storage


   The image is around half a gigabyte in size, but the actual image has
   a size of approximately 8.5 gigabytes, which means the resulting VM must
   have a disk size no smaller than 8.5GB.

    ```sh
    # qemu-img info flatcar-amd64-stable-4230.2.1-image.qcow2
    image: flatcar-amd64-stable-4230.2.1-image.qcow2
    file format: qcow2
    virtual size: 8.49 GiB (9116319744 bytes)
    disk size: 487 MiB
    cluster_size: 65536
    Format specific information:
        compat: 0.10
        compression type: zlib
        refcount bits: 16
    Child node '/file':
        filename: flatcar-amd64-stable-4230.2.1-image.qcow2
        protocol type: file
        file length: 490 MiB (513277952 bytes)
        disk size: 487 MiB
    ```

  see:
      - https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_download_file
      - https://github.com/bpg/terraform-provider-proxmox/issues/860
      - https://git.proxmox.com/?p=pve-storage.git;a=blob;f=PVE/API2/Storage/Status.pm;h=b838461db4b6d2076689ab72f861bfa4d9ee7923;hb=refs/heads/master
 */
resource "proxmox_virtual_environment_download_file" "flatcar_image" {
  content_type = "import"
  datastore_id = var.storage_images
  node_name    = var.target_node
  url          = local.FLATCAR_OS_IMAGE_URL
  file_name    = "${local.FLATCAR_BASE_FILENAME}-image.qcow2"
}

resource "proxmox_virtual_environment_download_file" "flatcar_uefi_vars" {
  content_type = "import"
  datastore_id = var.storage_images
  node_name    = var.target_node
  url          = local.FLATCAR_UEFI_VARS_IMAGE_URL
  file_name    = "${local.FLATCAR_BASE_FILENAME}-uefi_vars.qcow2"
}

resource "proxmox_virtual_environment_download_file" "flatcar_uefi_code" {
  content_type = "import"
  datastore_id = var.storage_images
  node_name    = var.target_node
  url          = local.FLATCAR_UEFI_CODE_IMAGE_URL
  file_name    = "${local.FLATCAR_BASE_FILENAME}-uefi_code.qcow2"
}

module "butane_storage_map" {
  source = "./storage-map"

  storage_id = proxmox_virtual_environment_file.flatcar_butane.id
  storage_map = var.storage_path_mapping
}
/**
  Put the ignition JSON into a snippet.

  This ignition goes through a translation from:
      1. a main butane YAML file
      2. a set of optional butane YAML snippet files
      3. all files are then translated as a Terraform template, with the following parameters:
          - vm_id
          - vm_name
          - vm_index
          - vm_count
      4. translated to JSON

  see:
    - https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_file
 */
resource "proxmox_virtual_environment_file" "flatcar_butane" {
  content_type = "snippets"
  datastore_id = var.storage_root
  node_name    = var.target_node

  source_raw {
    data      = data.ct_config.ignition_json[0].rendered
    file_name = "vm-${var.vm_id}.butane.json"
  }
}


/**
    Convert a butane configuration to an ignition JSON configuration. The template supports
    multiple instances (a count) so that each configuration can be slightly changed.

    see
      - https://github.com/poseidon/terraform-provider-ct
      - https://registry.terraform.io/providers/poseidon/ct/latest
      - https://registry.terraform.io/providers/poseidon/ct/latest/docs
      - https://www.flatcar.org/docs/latest/provisioning/config-transpiler/
      - https://developer.hashicorp.com/terraform/language/functions/templatefile
*/
data "ct_config" "ignition_json" {
  count = var.vm_count
  content = templatefile(var.butane_conf, {
    "vm_id"    = var.vm_count > 1 ? var.vm_id + count.index : var.vm_id
    "vm_name"  = var.vm_count > 1 ? "${var.vm_name}-${count.index + 1}" : var.vm_name
    "vm_count" = var.vm_count,
    "vm_index" = 0,
  })
  strict       = true
  pretty_print = true
  files_dir    = var.butane_snippet_path

  snippets = [
    for s in var.butane_conf_snippets : templatefile("${var.butane_snippet_path}/${s}", {
      "vm_id"    = var.vm_count > 1 ? var.vm_id + count.index : var.vm_id
      "vm_name"  = var.vm_count > 1 ? "${var.vm_name}-${count.index + 1}" : var.vm_name
      "vm_count" = var.vm_count,
      "vm_index" = count.index,
    })
  ]
}
