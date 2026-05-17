output "default_ip_address" {
  description = "Primary IP address reported by VMware Tools for the virtual machine"
  value       = vsphere_virtual_machine.vm.default_ip_address
}

output "guest_ip_addresses" {
  description = "All IP addresses reported by VMware Tools for the virtual machine"
  value       = vsphere_virtual_machine.vm.guest_ip_addresses
}

output "vm_id" {
  description = "Managed object identifier of the virtual machine"
  value       = vsphere_virtual_machine.vm.id
}

output "vm_name" {
  description = "Name of the virtual machine in vCenter"
  value       = vsphere_virtual_machine.vm.name
}
