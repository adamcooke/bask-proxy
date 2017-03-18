require 'procodile/config'
require 'procodile/control_client'
require 'procodile/cli'

module Bask
  class App

    def reload(options)
      @options = options
      @config = nil
    end

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
      ports[rand(ports.size)]
    end

    def environment
      @options['environment'] || 'development'
    end

    def process
      config.processes[@options['process'] || 'web']
    end

    def user
      @options['user'] || 'root'
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

    def suitable?
      return false unless present?
      return false unless process
      return false unless process.allocate_ports?
      return true
    end

    def ports
      instances.map { |p| p['port'] }
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

    def running_instances
      instances.select { |p| p['status'] == 'Running' }
    end

    def instances
      if status = get_supervisor_status
        if status['instances']
          status['instances'][self.process.name] || []
        else
          []
        end
      else
        []
      end
    end

    def process_running?
      instances.any? { |p| self.class.pid_active?(p['pid']) }
    end

    def processes_failed?
      if status = get_supervisor_status
        status['instances'][self.process.name].all? { |i| i['status'] == 'Failed' }
      else
        true
      end
    end

    def get_supervisor_status
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
          return true
        else
          if self.instances.empty?
            # Start the process within the existing supervisor.
            Bask.logger.info "Starting #{self.process.name} on existing supervisor for #{self.name}"
            Procodile::ControlClient.run(@config.sock_path, 'start_processes')
          else
            # There are instances, they're just not running which means they're likely failed.
            return false
          end
        end
      else
        # Start the supervisor with all processes
        Bask.logger.info "Starting supervisor for #{self.name}"
        command = "sudo -u #{user} #{Procodile.bin_path} start --root #{self.path} --procfile #{self.procfile_path} -e #{self.environment} --allocate-ports --stop-when-none --no-respawn"
        Process.spawn(command, :pgroup => true)
      end

      until self.instances.size > 0
        sleep 0.5

        if self.running_instances.empty?
          # If there are no running instances, the processes likely failed to start.
          return false
        end
      end

      true
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
