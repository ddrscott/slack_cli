require 'bundler/setup'
require 'slack_cli'

run SlackCLI::Server.new
