variable "use_single_nat" {
  description = "Set to true to use a single NAT gateway or false to use one NAT gateway per availability zone"
  type        = bool
  default     = true
}
