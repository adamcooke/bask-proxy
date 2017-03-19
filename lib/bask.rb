require 'logger'
require 'procodile'
require 'bask'
require 'bask/config'
require 'yaml'

module Bask

  CONFIG_PATHS = [
    File.expand_path('../../config.yml', __FILE__),
    File.join(ENV['HOME'], '.bask'),
    "/etc/bask.conf"
  ]

  def self.logger
    @logger ||= Logger.new(STDOUT)
  end

  def self.config
    @config ||= begin
      CONFIG_PATHS.each do |path|
        if File.file?(path)
          return Config.new(path)
        end
      end
      Config.new
    end
  end

  def self.current_pid
    (File.file?(config.pid_path) && File.read(config.pid_path).to_i) || false
  end

  def self.running?
    if pid = current_pid
      Process.getpgid(pid) ? true : false
    else
      false
    end
  rescue Errno::ESRCH
    false
  end

end
