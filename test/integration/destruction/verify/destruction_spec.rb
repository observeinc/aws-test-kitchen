require 'awspec'
require 'aws-sdk'
require 'aws-sdk-cloudwatchlogs'

provider = ENV['PROVIDER']
region = ENV['AWS_REGION']
user = ENV.fetch('USER', 'observe')

Aws.config[:region] = region

RSpec.configure do |config|
  config.before(:each) do
    sts = Aws::STS::Client.new
    account_id = sts.get_caller_identity.account

    # Specify the AWS Account ID
    ENV['AWS_ACCOUNT_ID'] = account_id
  end
end

# Get all CloudWatch log groups
logs = Aws::CloudWatchLogs::Client.new

logs.describe_log_groups.log_groups.each do |log_group|
  # Filter out the ones that match your prefix
  if log_group.log_group_name.start_with?("/aws/lambda/#{provider}-#{user}")
    describe cloudwatch_logs(log_group.log_group_name) do
      it { should_not exist }
    end
  end
end