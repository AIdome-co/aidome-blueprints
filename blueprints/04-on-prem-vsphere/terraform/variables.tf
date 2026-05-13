variable "allowed_ssh_cidr" {
  description = "Management CIDR that is allowed to connect to the VM over SSH"
  type        = string

  validation {
    condition     = !contains(["0.0.0.0/0", "::/0"], var.allowed_ssh_cidr)
    error_message = "allowed_ssh_cidr must be a narrow management CIDR, not 0.0.0.0/0 or ::/0."
  }
}

variable "annotation" {
  description = "Optional annotation written to the vSphere virtual machine"
  type        = string
  default     = "Managed by Terraform for the AIdome VMware vSphere single-node blueprint"
}

variable "cluster_name" {
  description = "Name of the vSphere compute cluster that hosts the VM"
  type        = string
}

variable "datacenter_name" {
  description = "Name of the vSphere datacenter that contains the target resources"
  type        = string
}

variable "datastore_name" {
  description = "Name of the datastore where the VM is stored"
  type        = string
}

variable "dns_servers" {
  description = "DNS servers configured inside the guest"
  type        = list(string)

  validation {
    condition     = length(var.dns_servers) > 0
    error_message = "dns_servers must contain at least one resolver."
  }
}

variable "domain_name" {
  description = "DNS search domain configured for the guest"
  type        = string
  default     = "localdomain"
}

variable "eagerly_scrub" {
  description = "When thin_provisioned is false, set eagerly_scrub to true for eager-zeroed thick provisioning"
  type        = bool
  default     = true
}

variable "enable_cpu_hot_add" {
  description = "Enable CPU hot-add on the virtual machine"
  type        = bool
  default     = false
}

variable "enable_memory_hot_add" {
  description = "Enable memory hot-add on the virtual machine"
  type        = bool
  default     = false
}

variable "enable_secure_boot" {
  description = "Enable UEFI Secure Boot for the virtual machine"
  type        = bool
  default     = true
}

variable "gateway" {
  description = "Default IPv4 gateway configured inside the guest"
  type        = string
}

variable "guest_network_interface_name" {
  description = "Guest interface name used in cloud-init network config (for example ens160 or ens192)"
  type        = string
  default     = "ens160"
}

variable "ip_address" {
  description = "Static IPv4 address assigned to the guest"
  type        = string
}

variable "memory_mb" {
  description = "Memory assigned to the virtual machine in MiB"
  type        = number
  default     = 8192
}

variable "network_name" {
  description = "Name of the vSphere port group attached to the virtual machine"
  type        = string
}

variable "num_cpus" {
  description = "Number of vCPUs assigned to the virtual machine"
  type        = number
  default     = 4
}

variable "prefix_length" {
  description = "IPv4 prefix length used by the guest network configuration"
  type        = number

  validation {
    condition     = var.prefix_length >= 1 && var.prefix_length <= 32
    error_message = "prefix_length must be between 1 and 32."
  }
}

variable "root_disk_size_gb" {
  description = "Root disk size for the cloned virtual machine in GiB; must be at least as large as the template disk"
  type        = number
  default     = 100
}

variable "ssh_public_key" {
  description = "SSH public key injected for the aidome-ops account"
  type        = string
}

variable "template_name" {
  description = "Name of the source Ubuntu cloud-image template in vCenter"
  type        = string
}

variable "thin_provisioned" {
  description = "Use thin-provisioned storage for the root disk when true"
  type        = bool
  default     = false
}

variable "vm_folder" {
  description = "Optional vSphere folder path for the virtual machine"
  type        = string
  default     = null
}

variable "vm_hostname" {
  description = "Hostname configured inside the guest; defaults to vm_name when null"
  type        = string
  default     = null
}

variable "vm_name" {
  description = "Display name of the virtual machine in vCenter"
  type        = string
}
