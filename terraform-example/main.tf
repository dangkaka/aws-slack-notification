provider "aws" {
  region  = "${var.aws_region}"
  profile = "${var.aws_profile}"
}

resource "aws_instance" "example" {
  ami           = "ami-de90a5a2"
  instance_type = "t2.micro"
}

resource "aws_cloudwatch_metric_alarm" "cpu-high" {
  alarm_name          = "example-cpu-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  period              = "60"
  evaluation_periods  = "2"
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  threshold           = "80"

  dimensions {
    DBInstanceIdentifier = "${aws_instance.example.id}"
  }
  alarm_description = "Triggers when the EC2 uses more than 80% CPU"
  alarm_actions     = ["${aws_sns_topic.sns-alarms.arn}"]
}

# CloudWatch alarm notifications
resource "aws_sns_topic" "sns-alarms" {
  name         = "example-notifications"
  display_name = "Example Notifications"
}

resource "aws_sns_topic_subscription" "slack" {
  topic_arn = "${aws_sns_topic.sns-alarms.arn}"
  protocol  = "lambda"
  endpoint  = "${aws_lambda_function.slack.arn}"
}

resource "aws_iam_role" "lambda" {
  name = "ExampleLambdaRole"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "lambda" {
  name = "ExampleAllowCloudwatch"
  role = "${aws_iam_role.lambda.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:DescribeLogStreams",
        "logs:PutLogEvents"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_lambda_function" "slack" {
  filename         = "${path.module}/../deployment.zip"
  function_name    = "ExampleNotifyCloudWatchAlarmsOnSlack"
  description      = "Slack notifier from CloudWatch"
  role             = "${aws_iam_role.lambda.arn}"
  handler          = "main"
  runtime          = "go1.x"

  environment {
    variables = {
      SLACK_WEBHOOK    = "${var.slack_webhook}"
    }
  }
}

resource "aws_lambda_permission" "sns" {
  statement_id  = "AllowExecutionFromExampleSNS"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.slack.function_name}"
  principal     = "sns.amazonaws.com"
  source_arn    = "${aws_sns_topic.sns-alarms.arn}"
}
