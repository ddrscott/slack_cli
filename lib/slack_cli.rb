require 'dotenv/load' # must come first

# The rest should be sorted unless there are dependencies
require 'cgi'
require 'digest/md5'
require 'erb'
require 'eventmachine'
require 'websocket/eventmachine/client'
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
require 'slack_cli/live'

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
    $stderr.puts "Go to \e[1;32mhttp://localhost:65187/\e[0m to authenticate Slack CLI."
    t = Thread.new do
      Rack::Handler::WEBrick.run(cli_app, webrick_options) do |server|
        cli_app.webbrick = server
      end
    end
    t.join
    if File.file?(cli_app.authorization_path)
      $stderr.puts "\e[32mSuccessfully authenticated.\e[0m"
    else
      $stderr.puts 'There was a problem authorizing the token!'
      $stderr.puts log_string_io.read
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
    cache_key = Digest::MD5.hexdigest(url).gsub('=', '')
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
      raise Error, json.inspect
    end
    File.open(full_cache_path, 'w'){|f| f << data} if save
    json
  end

  def slack_post(path:, json:)
    uri = URI.parse("https://slack.com/api/#{path}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    http.set_debug_output($stderr) if $DEBUG
    header = {
      'Authorization' => "Bearer #{access_token}",
      'Content-Type' => 'application/json; charset=utf-8'
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
    slack_post(
      path: 'chat.postMessage',
      json: { channel: channel_id(channel), text: text, as_user: true}
    )
  end

  def tty
    @tty ||= File.open('/dev/tty', 'a')
  end

  def rtm_connect(**params, &block)
    resp = slack_get(path: 'rtm.connect', refresh: true)
    tty.puts resp.to_json
    ws = WebSocket::EventMachine::Client.connect(uri: resp['url'])
    ws.onopen do
      tty.puts({status: 'connected'}.to_json)
      # ws.send(connect_payload.to_json)
    end

    ws.onmessage do |msg, type|
      if block
        block.call(JSON.parse(msg))
      else
        puts msg
      end
    end

    ws.onclose do |code, reason|
      tty.puts({status: 'disconnected', code: code, reason: reason}.to_json)
      rtm_connect
    end
  end

  def channel_id(channel)
    result = users_by_name[channel] ||    \
             channels_by_name[channel] || \
             raise("No channel or user found for `#{channel}`")
    result['id']
  end
end
