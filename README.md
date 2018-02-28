# Slack CLI

A Slack CLI tool.

## Usage

```sh
$ slack help
Commands:
  slack authorize                        # Authorize the CLI and get an access_token
  slack help [COMMAND]                   # Describe available commands or one specific command
  slack post TEXT -c, --channel=CHANNEL  # Post message to channel or user
```

## Installation

Install from Rubygems

```sh
$ gem install slack_cli
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ddrscott/slack_cli.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
