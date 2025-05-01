# outputs.tf
output "hello_world_file" {
  value = local_file.hello_world.filename
}
