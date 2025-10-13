/*
  Get this password for the 'admin' user with:
     > terraform output -json dozzle_passwords
*/
output dozzle_passwords {
  description = "The username/password pairs (as a map(string)) for dozzle users"
  value = module.dozzle_users.passwords
  sensitive = true
}

output db_cacti_password {
  value = random_password.db_cacti_password.result
  sensitive = true
}

output db_root_password {
  value = random_password.db_root_password.result
  sensitive = true
}
