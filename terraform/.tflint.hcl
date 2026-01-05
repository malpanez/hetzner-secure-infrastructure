# TFLint Configuration
# Terraform linting and validation

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

# Hetzner Cloud plugin disabled - ruleset repository archived
# plugin "hcloud" {
#   enabled = true
#   version = "0.3.0"
#   source  = "github.com/hetznercloud/tflint-ruleset-hcloud"
# }

# Rule configurations
rule "terraform_deprecated_index" {
  enabled = true
}

rule "terraform_deprecated_interpolation" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}

rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_module_pinned_source" {
  enabled = true
}

rule "terraform_naming_convention" {
  enabled = true
  format  = "snake_case"
}

rule "terraform_required_providers" {
  enabled = true
}

rule "terraform_required_version" {
  enabled = true
}

rule "terraform_standard_module_structure" {
  enabled = true
}

rule "terraform_typed_variables" {
  enabled = true
}

rule "terraform_unused_declarations" {
  enabled = true
}

rule "terraform_unused_required_providers" {
  enabled = true
}

rule "terraform_workspace_remote" {
  enabled = true
}
