resource "azuread_group" "department_groups" {
  for_each = {
    for group in flatten([
      for dept in local.departments : [
        for type in local.group_types : {
          key  = "${dept}-${type}"
          name = "${local.naming_prefix}-${dept}-${type}"
        }
      ]
    ]) : group.key => group
  }

  display_name     = each.value.name
  security_enabled = true

  description = "${var.environment} Microsoft Entra ID security group managed by Terraform for ${each.value.name}."
}