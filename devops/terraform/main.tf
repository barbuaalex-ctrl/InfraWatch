data "aws_ssm_parameter" "linux_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_key_pair" "agent" {
  key_name_prefix = "infrawatch-"
  public_key      = file(pathexpand("~/.ssh/infrawatch-ec2.pub"))

  lifecycle {
    ignore_changes = [public_key]
  }
}

resource "aws_instance" "agent" {
  ami                         = data.aws_ssm_parameter.linux_ami.value
  instance_type               = "t3.micro"
  key_name                    = aws_key_pair.agent.key_name
  vpc_security_group_ids      = [aws_security_group.agent.id]
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/user-data.sh", {
    agent_code    = filebase64("${path.module}/../../app/agent/linux/agent.py")
    agent_version = filebase64("${path.module}/../../app/agent/version.json")
  })

  user_data_replace_on_change = true

  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  credit_specification {
    cpu_credits = "standard"
  }

  metadata_options {
    http_tokens = "required"
  }

  tags = {
    Name = "infrawatch-monitored-server"
  }
}

output "server_ip" {
  value = aws_instance.agent.public_ip
}