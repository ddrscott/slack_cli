# rubocop:disable all
module SlackCLI
  class Live
    include SlackCLI

    attr_accessor :lines, :title, :channel, :delay

    def initialize(channel:, title: nil, delay: 0.2)
      @lines = ['']
      @title = title
      @channel = channel
      @channel_id = channel_id(channel)
      @delay = delay
      @ts = nil
    end

    def payload
      {
        channel: @channel_id,
        as_user: true,
        parse: 'none',
        attachments: [attachment],
        ts: @ts
      }
    end

    def default_title
      '[Live chat started by Slack CLI]'
    end

    def attachment
      {
        text: lines.join("\n"),
        title: title || default_title
      }
    end

    def final_msg
      '[session ended]'
    end

    def watch_changes
      sleep(delay)
      prev = nil
      while (line = Readline.line_buffer)
        next if prev == line
        lines[-1] = line
        prev = line
        slack_post(path: 'chat.update', json: payload)
        sleep(delay)
      end
    end

    def run
      trap('SIGINT') { exit(130) }

      tty.puts("\e[32m[Quit with <CTRL-C>]\e[0m")
      first = slack_post(path: 'chat.postMessage', json: payload)
      @channel_id = first['channel']
      @ts = first['ts']

      # setup thread to listen for changes
      Thread.abort_on_exception
      Thread.new { watch_changes }

      while (line = Readline.readline("#{@channel}> ", true))
        lines[-1] = line
        lines << ''
        slack_post(path: 'chat.update', json: payload)
      end
    ensure
      lines << final_msg
      slack_post(path: 'chat.update', json: payload)
      tty.puts(final_msg)
    end
  end
end
