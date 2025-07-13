variable "storage_map" {
  description = "Map from storage name to storage path"
  type        = map(string)
}

variable "storage_id" {
  description = "Storage identifier in the form 'name:type/file_name'"
  type        = string
}

locals {
  colon_split  = split(":", var.storage_id)
  storage_name = local.colon_split[0]
  storage_rest = local.colon_split[1]

  base_path    = var.storage_map[local.storage_name]
  output_path  = "${local.base_path}/${local.storage_rest}"
}

output "path" {
  description = "Full resolved path on disk"
  value       = local.output_path
}