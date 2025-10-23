variable "project" {
     type = string  
     default = "signalfind" 
     }
variable "env"     { type = string }
variable "region"  { 
    type = string  
    default = "ap-southeast-2" 
    }

# GuardDuty & SecurityHub toggles would live here; WAF ACLs, managed rule groups, etc.
# For brevity, this is a placeholder module.
