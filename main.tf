provider "aws" {
  region = "ca-central-1"
}

###########################################################################
#
# Create a group
#
###########################################################################

resource "aws_iam_group" "this" {
  name = "tf-group"
  path = "/groups/"
}


###########################################################################
#
# Create 2 users
#
###########################################################################

resource "aws_iam_user" "this" {
  count = 2

  name = "tf-user-${count.index}"
}

###########################################################################
#
# Attach 2 users to the group
#
###########################################################################

resource "aws_iam_group_membership" "this" {
  name = "tf-testing-group-membership"

  users = aws_iam_user.this.*.name

  group = aws_iam_group.this.name
}

###########################################################################
#
# Provides an IAM inline Policies attached to a group.
#
###########################################################################

resource "aws_iam_group_policy" "this" {
  name  = "tf_group_inline_policy"
  group = aws_iam_group.this.name

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:Describe*",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

###########################################################################
#
# get a aws managed policy and attach it to the group
#
###########################################################################

data "aws_iam_policy" "this" {
  arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess" 
}

resource "aws_iam_group_policy_attachment" "this-aws" {
  group      = aws_iam_group.this.name
  policy_arn = data.aws_iam_policy.this.arn
}

###########################################################################
#
# Create a customer managed policy
#
###########################################################################

resource "aws_iam_policy" "this" {
  name        = "tf-customer-managed-policy"
  path        = "/policy/"
  description = "My test customer managed policy"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "efs:*",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_group_policy_attachment" "this-cmp" {
  group      = aws_iam_group.this.name
  policy_arn = aws_iam_policy.this.arn
}

###########################################################################
#
# Create the third user
#
###########################################################################

resource "aws_iam_user" "user3" {
  name = "tf-user-3"
  path = "/users/"

  permissions_boundary = "arn:aws:iam::aws:policy/AdministratorAccess"

  force_destroy = false

  tags = {
    fullpath = "/users/tf-user-3"
  }
}

# Provides an IAM access key.
resource "aws_iam_access_key" "user3" {
  user = aws_iam_user.user3.name
}

# add an inline policy to the user3
resource "aws_iam_user_policy" "user3_inline" {
  name = "user3-inline-policy"
  user = aws_iam_user.user3.name

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ecr:*",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

# add an aws managed policy to the user3
resource "aws_iam_user_policy_attachment" "user3-aws" {
  user       = aws_iam_user.user3.name
  policy_arn = "arn:aws:iam::aws:policy/AlexaForBusinessDeviceSetup"
}

# add the user3 to the group
resource "aws_iam_user_group_membership" "user3-to-group" {
  user = aws_iam_user.user3.name

  groups = [
    aws_iam_group.this.name,
  ]
}

###########################################################################
#
# Create an ec2 service role
#
###########################################################################

resource "aws_iam_role" "ec2_role" {
  name = "tf-ec2-role"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Name = "ec2_role"
  }
}

###########################################################################
#
# Create an asg service role Using Data Source for Assume Role Policy
#
###########################################################################

data "aws_iam_policy_document" "asg-assume-role-policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["autoscaling.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "asg_role" {
  name               = "tf-asg-role"
  path               = "/system/"
  assume_role_policy = data.aws_iam_policy_document.asg-assume-role-policy.json

  tags = {
    Name = "asg_role"
  }
}

###########################################################################
#
# Create an ec2 service role using Inline Policies and managed policies
#
###########################################################################

resource "aws_iam_role" "ec2_role_inline" {
  name = "tf-ec2-role-inline"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  inline_policy {
    name = "my_inline_policy"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action   = ["ec2:Describe*"]
          Effect   = "Allow"
          Resource = "*"
        },
      ]
    })
  }

  inline_policy {
    name   = "policy-8675309"
    policy = data.aws_iam_policy_document.inline_policy.json
  }

  tags = {
    Name = "ec2_role_inline"
  }

  # attach managed policies to this role
  managed_policy_arns = [aws_iam_policy.policy_one.arn, aws_iam_policy.policy_two.arn, "arn:aws:iam::aws:policy/AlexaForBusinessDeviceSetup"]

  # boundary permission
  permissions_boundary = "arn:aws:iam::aws:policy/AdministratorAccess"
}

data "aws_iam_policy_document" "inline_policy" {
  statement {
    actions   = ["ec2:DescribeAccountAttributes"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "policy_one" {
  name = "policy-618033"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["efs:*"]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_policy" "policy_two" {
  name = "policy-381966"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["s3:ListAllMyBuckets", "s3:ListBucket", "s3:HeadBucket"]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

###########################################################################
#
# Create an ec2 service role using Inline Policies and attach managed policies to it
#
###########################################################################

resource "aws_iam_role_policy" "role_policy_2" {
  name = "tf-role-policy-2"
  role = aws_iam_role.role_2.id

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:Describe*",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role" "role_2" {
  name = "tf-role-2"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "role-2-attach" {
  role       = aws_iam_role.role_2.name
  policy_arn = aws_iam_policy.policy_two.arn
}