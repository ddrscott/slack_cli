# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'slack_cli/version'

Gem::Specification.new do |spec|
  spec.name          = 'slack_cli'
  spec.version       = SlackCLI::VERSION
  spec.authors       = ['Scott Pierce']
  spec.email         = ['ddrscott@gmail.com']

  spec.summary       = 'Slack CLI'
  spec.homepage      = 'https://github.com/ddrscott/slack_cli'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.15'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.0'

  spec.add_dependency 'dotenv', '~> 2.2'
  spec.add_dependency 'puma', '~> 3.11'
  spec.add_dependency 'rack', '~> 2.0'
  spec.add_dependency 'thor', '~> 0.20'
  spec.add_dependency 'eventmachine', '~> 1.2'
  spec.add_dependency 'websocket-eventmachine-client', '~> 1.2'
end
