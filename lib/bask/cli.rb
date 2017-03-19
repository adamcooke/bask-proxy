module Bask
  class CLI

    def initialize(args)
      @args = args
    end

    def dispatch(command)
      command = 'help' if command.nil?
      public_send(command) unless command == 'dispatch'
    end

    def help
      puts "Help goes here!"
    end

    def run
      Thread.new do
        require 'bask/dns_server'
        server = Bask::DNSServer.new
        server.run
      end.tap { |t| t.abort_on_exception = true }
      require 'bask/web_server'
      server = Bask::WebServer.new
      server.run
    end

    def start
      if Bask.running?
        $stderr.puts "Bask is already running (PID: #{Bask.current_pid})"
        exit 1
      else
        pid = fork do
          STDOUT.reopen(Bask.config.log_path, 'a')
          STDOUT.sync = true
          STDERR.reopen(Bask.config.log_path, 'a')
          STDERR.sync = true
          self.run
        end
        Process.detach(pid)
        File.open(Bask.config.pid_path, 'w') { |f| f.write(pid.to_s + "\n")}
        puts "Bask started (PID: #{pid})"
        exit 0
      end
    end

    def stop
      if Bask.running? && pid = Bask.current_pid
        Process.kill('TERM', pid)
        puts "Sent TERM to Bask (PID: #{pid})"
        exit 0
      else
        $stderr.puts "Bask is not running"
        exit 1
      end
    end

    def status
      puts Bask.running? ? "Bask is running" : "Bask is not running"
      puts "Config file at #{Bask.config.path}"
      puts
      for app in Bask.config.apps.values
        puts "#{app.name}: #{app.path}: #{app.status}"
      end
      exit 0
    end

    def app
      app_name = @args.shift
      if app = Bask.config.apps[app_name]
        args = @args.join(' ')
        exec("sudo -u #{app.user} procodile #{args} --root #{app.path}")
      else
        $stderr.puts "No app found with name '#{app_name}'"
        exit 1
      end
    end

    def add
      pwd = FileUtils.pwd
      if File.file?(File.join(pwd, 'Procfile'))
        if current = Bask.config.apps.values.select { |p| p.path == pwd }.first
          $stderr.puts "An app in this directory has already been added (#{current.name})"
          exit 1
        end

        app_name = pwd.split('/').last
        if current = Bask.config.apps[app_name]
          $stderr.puts "An app with this name already exists (#{app_name})"
          exit 1
        end

        hash = {'path' => pwd, 'user' => ENV['SUDO_USER'], 'process' => 'web'}
        Bask.config.add_app(app_name, hash)
        puts "Added #{app_name} to Bask configuration."
        exit 0
      else
        $stderr.puts "No procfile in current directory"
        exit 1
      end
    end

    def remove
      app_name = @args.shift
      if Bask.config.apps[app_name]
        Bask.config.remove_app(app_name)
        puts "Removed #{app_name} from Bask configuration."
        exit 0
      else
        $stderr.puts "No app named #{app_name}"
        exit 1
      end
    end

  end
end
