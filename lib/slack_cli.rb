require 'dotenv/load' # must come first

# The rest should be sorted unless there are dependencies
require 'cgi'
require 'digest/md5'
require 'erb'
require 'fileutils'
require 'json'
require 'logger'
require 'net/http'
require 'openssl'
require 'open-uri'
require 'rack'
require 'rack/handler/webrick'
require 'rack/request'

require 'slack_cli/server'

# Main module
module SlackCLI

  class Error < StandardError; end

  module_function

  def string_logger
    @logger ||= Logger.new(log_string_io)
  end

  def log_string_io
    @log_string_io ||= StringIO.new
  end

  def clear_cache
    FileUtils.rm_rf cache_path
  end

  def webrick_options
    {
      Port: 65187,
      Logger: string_logger,
      AccessLog: string_logger
    }
  end

  def cli_app
    @cli_app ||= SlackCLI::Server.new
  end

  def authorize
    puts "Go to \e[1;32mhttp://localhost:65187/\e[0m to authenticate Slack CLI."
    t = Thread.new do
      Rack::Handler::WEBrick.run(cli_app, webrick_options) do |server|
        cli_app.webbrick = server
      end
    end
    t.join
    if File.file?(cli_app.authorization_path)
      puts "\e[32mSuccessfully authenticated.\e[0m"
    else
      puts 'There was a problem authorizing the token!'
      puts log_string_io.read
    end
  end

  def access_token
    @access_token ||= begin
      File.file?(cli_app.authorization_path) || raise("Application not authorized! Try calling `slack authorize`")
      JSON.parse(File.read(cli_app.authorization_path))['access_token']
    end
  end

  def bot_token
    @access_token ||= begin
      File.file?(cli_app.authorization_path) || raise("Application not authorized! Try calling `slack authorize`")
      JSON.parse(File.read(cli_app.authorization_path))['bot']['bot_access_token']
    end
  end

  def cache_path
    @cache_path ||= begin
      File.join(cli_app.config_path, 'cache').tap do |t|
        FileUtils.mkdir_p(t)
      end
    end
  end

  def slack_get(path:, refresh: true)
    url = "https://slack.com/api/#{path}"
    cache_key = Digest::MD5.base64digest(url).gsub('=', '')
    full_cache_path = File.join(cache_path, cache_key)
    save = false
    data = if refresh == true || !File.file?(full_cache_path)
      save = true
      open(
        url,
        'Authorization' => "Bearer #{access_token}",
        'Content-type' => 'application/json'
      ).read
    else
      File.read(full_cache_path)
    end

    json = JSON.parse(data)
    if (error = json['error'])
      raise Error, "[#{error['code']}] #{error['text']}"
    end
    File.open(full_cache_path, 'w'){|f| f << data} if save
    json
  end

  # http.use_ssl = true
  # http.verify_mode = OpenSSL::SSL::VERIFY_PEER
  # http.set_debug_output($stdout) if $DEBUG
  def slack_post(path:, json:)
    uri = URI.parse("https://slack.com/api/#{path}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    http.set_debug_output($stdout) if $DEBUG
    header = {
      'Authorization' => "Bearer #{access_token}",
      'Content-Type' => 'application/json'
    }
    request = Net::HTTP::Post.new(uri, header)
    request.body = json.to_json
    resp = http.request(request)
    JSON.parse(resp.body)
  end

  def channels(refresh: false)
    slack_get(path: 'channels.list', refresh: refresh)
  end

  def channels_by_name
    channels['channels'].each_with_object({}) do |row, agg|
      agg[row['name']] = row
    end
  end

  def users(refresh: false)
    slack_get(path: 'users.list', refresh: refresh)
  end

  def users_by_name
    users['members'].each_with_object({}) do |row, agg|
      agg[row['name']] = row
    end
  end

  def post(channel:, text:)
    place = users_by_name[channel] || channels_by_name[channel]
    if place
      slack_post(
        path: 'chat.postMessage',
        json: { channel: place['id'], text: text }
      )
    else
      raise "No channel or user found for `#{channel}`"
    end
  end
end
