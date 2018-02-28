require 'dotenv/load' # must come first

# The rest should be sorted unless there are dependencies
require 'cgi'
require 'erb'
require 'fileutils'
require 'json'
require 'open-uri'
require 'rack/request'

class SlackCliServer
  def callback(env)
    request = Rack::Request.new(env)
    slack_resp = fetch_token(code: request.params['code'])
    [302, { 'Location' => "http://localhost:65187/token/?json=#{CGI.escape(slack_resp)}" }, ['redirecting...']]
  end

  def fetch_token(code:)
    base_url = 'https://slack.com/api/oauth.access'
    query = {
      client_id: client_id,
      client_secret: client_secret,
      code: code
    }
    query_uri = query.map { |k, v| "#{k}=#{v}" }.join('&')
    open("#{base_url}?#{query_uri}").read
  end

  def save_token(env)
    request = Rack::Request.new(env)
    json = JSON.parse(request['json'])
    FileUtils.mkdir_p(config_path)
    File.open(access_token_path, 'w'){|f| f << json['access_token']}
    render_view(src: 'views/save_token.erb', binding: binding)
  end

  def render_view(src:, binding:, status: 200)
    erb = ERB.new(File.read(src))
    erb.filename = src
    erb.result(binding)
    [status, {'Content Type' => 'text/html'}, [erb.result(binding)]]
  end

  def access_token_path
    File.join(config_path, 'access_token')
  end

  def config_path
    File.expand_path(File.join('~', '.config', 'slack_cli'))
  end

  def call(env)
    if env['REQUEST_PATH'] == '/callback/'
      callback(env)
    elsif env['REQUEST_PATH'] == '/token/'
      save_token(env)
    else
      [404, {}, ['File not found']]
    end
  end

  def authorize_url
    "https://slack.com/oauth/authorize?client_id=#{client_id}&scope=#{scope}&then=#{CGI.escape(save_token_url)}"
  end

  def save_token_url(token:)
    "http://localhost:65187/token/#{token}"
  end

  def client_id
    ENV['SLACK_CLIENT_ID'] || raise('SLACK_CLIENT_ID not found in ENV!')
  end

  def client_secret
    ENV['SLACK_SECRET'] || raise('SLACK_SECRET not found in ENV!')
  end

  def scope
    ENV['SLACK_SCOPE'] || raise('SLACK_SCOPE not found in ENV!')
  end
end
run SlackCliServer.new
