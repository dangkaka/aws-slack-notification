output "ec2_example_public_ip" {
  value = "${aws_instance.example.public_ip}"
}
