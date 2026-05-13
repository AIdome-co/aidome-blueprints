provider "vsphere" {
  allow_unverified_ssl = false
}

locals {
  effective_vm_hostname = coalesce(var.vm_hostname, var.vm_name)

  cloud_init_user_data = templatefile("${path.module}/../scripts/cloud-init-deb.yaml", {
    allowed_ssh_cidr = var.allowed_ssh_cidr
    domain_name      = var.domain_name
    fqdn             = "${local.effective_vm_hostname}.${var.domain_name}"
    ssh_public_key   = var.ssh_public_key
    vm_hostname      = local.effective_vm_hostname
  })

  metadata = templatefile("${path.module}/../scripts/metadata.yaml", {
    dns_servers                  = jsonencode(var.dns_servers)
    gateway                      = var.gateway
    guest_network_interface_name = var.guest_network_interface_name
    ip_address                   = var.ip_address
    prefix_length                = var.prefix_length
    vm_hostname                  = local.effective_vm_hostname
  })
}

data "vsphere_compute_cluster" "cluster" {
  datacenter_id = data.vsphere_datacenter.datacenter.id
  name          = var.cluster_name
}

data "vsphere_datacenter" "datacenter" {
  name = var.datacenter_name
}

data "vsphere_datastore" "datastore" {
  datacenter_id = data.vsphere_datacenter.datacenter.id
  name          = var.datastore_name
}

data "vsphere_network" "network" {
  datacenter_id = data.vsphere_datacenter.datacenter.id
  name          = var.network_name
}

data "vsphere_virtual_machine" "template" {
  datacenter_id = data.vsphere_datacenter.datacenter.id
  name          = var.template_name
}

resource "vsphere_virtual_machine" "vm" {
  annotation             = var.annotation
  datastore_id           = data.vsphere_datastore.datastore.id
  firmware               = "efi"
  folder                 = var.vm_folder
  guest_id               = data.vsphere_virtual_machine.template.guest_id
  memory                 = var.memory_mb
  memory_hot_add_enabled = var.enable_memory_hot_add
  name                   = var.vm_name
  num_cpus               = var.num_cpus
  resource_pool_id       = data.vsphere_compute_cluster.cluster.resource_pool_id
  scsi_type              = data.vsphere_virtual_machine.template.scsi_type

  efi_secure_boot_enabled = var.enable_secure_boot
  cpu_hot_add_enabled     = var.enable_cpu_hot_add

  clone {
    template_uuid = data.vsphere_virtual_machine.template.id
  }

  disk {
    eagerly_scrub    = var.thin_provisioned ? false : var.eagerly_scrub
    label            = "disk0"
    size             = max(var.root_disk_size_gb, data.vsphere_virtual_machine.template.disks[0].size)
    thin_provisioned = var.thin_provisioned
  }

  network_interface {
    adapter_type = "vmxnet3"
    network_id   = data.vsphere_network.network.id
  }

  extra_config = {
    # Metadata is intentionally base64-only because the rendered payload is small and keeping it
    # human-readable simplifies VMware GuestInfo troubleshooting from the guest console.
    "guestinfo.metadata"          = base64encode(local.metadata)
    "guestinfo.metadata.encoding" = "base64"
    "guestinfo.userdata"          = base64gzip(local.cloud_init_user_data)
    "guestinfo.userdata.encoding" = "gzip+base64"
  }

  wait_for_guest_ip_timeout  = var.wait_for_guest_ip_timeout
  wait_for_guest_net_timeout = var.wait_for_guest_net_timeout

  lifecycle {
    precondition {
      condition     = length(data.vsphere_virtual_machine.template.disks) > 0
      error_message = "The selected template must expose at least one disk."
    }

    precondition {
      condition     = !(var.thin_provisioned && var.eagerly_scrub)
      error_message = "eagerly_scrub cannot be true when thin_provisioned is true."
    }
  }
}
