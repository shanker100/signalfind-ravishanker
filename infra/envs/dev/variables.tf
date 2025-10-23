variable "project" { 
    type = string 
    default = "signalfind" 
    }
variable "env"     { type = string }
variable "region"  {
     type = string 
     default = "ap-southeast-2" 
     }
 variable "state_bucket" { type = string }
 variable "lock_table"   { type = string }


variable "domain_name"  { 
    type = string 
    default = null 
    }

