require 'dotenv/load' # must come first

# The rest should be sorted unless there are dependencies
require 'cgi'
require 'erb'
require 'fileutils'
require 'json'
require 'open-uri'
require 'rack/request'

require 'slack_cli/server'

# Main module
module SlackCLI
end
