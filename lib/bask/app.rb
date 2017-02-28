require 'procodile/config'
require 'procodile/control_client'
require 'procodile/cli'

module Bask
  class App

    def initialize(name, options = {})
      @name = name
      @options = options
    end

    def name
      @name
    end

    def path
      @options['path']
    end

    def port
      @options['port'].to_i
    end

    def environment
      @options['environment'] || 'development'
    end

    def process
      @options['process'] || 'web'
    end

    def procfile_path
      @options['procfile'] || File.join(self.path, 'Procfile')
    end

    def present?
      self.path && File.directory?(self.path) && File.exist?(procfile_path)
    end

    def config
      @config ||= Procodile::Config.new(path, environment, procfile_path)
    end

    def current_pid
      if File.exist?(config.supervisor_pid_path)
        pid_file = File.read(config.supervisor_pid_path).strip
        pid_file.length > 0 ? pid_file.to_i : nil
      else
        nil
      end
    end

    def supervisor_running?
      if pid = current_pid
        self.class.pid_active?(pid)
      else
        false
      end
    end

    def process_status
      if status = supervisor_status
        (status['instances'] && status['instances'][self.process].first) || false
      else
        false
      end
    end

    def process_running?
      if status = process_status
        self.class.pid_active?(status['pid'])
      else
        false
      end
    end

    def supervisor_status
      if supervisor_running?
        Procodile::ControlClient.run(@config.sock_path, 'status')
      else
        false
      end
    end

    def start
      @last_request_at = Time.now
      if supervisor_running?
        if process_running?
          true
        else
          # Start the process within the existing supervisor.
          Bask.logger.info "Starting #{self.process} on existing supervisor for #{self.name}"
          Procodile::ControlClient.run(@config.sock_path, 'start_processes')
        end
      else
        # Start the supervisor with all processes
        Bask.logger.info "Starting supervisor for #{self.name}"
        Process.spawn("#{Procodile.bin_path} start --root #{self.path} --procfile #{self.procfile_path} -e #{self.environment}", :pgroup => true)
      end
    end

    def ready?
      supervisor_running? && process_running?
    end

    def self.pid_active?(pid)
      ::Process.getpgid(pid) ? true : false
    rescue Errno::ESRCH
      false
    end

  end
end
