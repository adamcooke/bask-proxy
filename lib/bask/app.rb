require 'fileutils'
require 'procodile/config'

module Bask
  class App

    def initialize(name, options = {})
      @name = name
      @options = options
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

    def procfile_path
      @options['procfile'] || File.join(self.path, 'Procfile')
    end

    def present?
      self.path && File.directory?(self.path) && File.exist?(procfile_path)
    end

    def config
      @config ||= Procodile::Config.new(path, environment, procfile_path)
    end

    def pid_path
      File.join(config.pid_root, 'procodile.pid')
    end

    def current_pid
      if File.exist?(pid_path)
        pid_file = File.read(pid_path).strip
        pid_file.length > 0 ? pid_file.to_i : nil
      else
        nil
      end
    end

    def supervisor_running?
      if pid = current_pid
        ::Process.getpgid(pid) ? true : false
      else
        false
      end
    rescue Errno::ESRCH
      false
    end

    def ready?
      supervisor_running?
    end

  end
end
