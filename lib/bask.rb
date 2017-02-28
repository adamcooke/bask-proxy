require 'logger'
require 'procodile'
require 'bask'
require 'bask/config'
require 'yaml'

module Bask

  CONFIG_PATHS = [
    File.expand_path('../../config.yml', __FILE__),
    "/etc/bask.conf"
  ]

  def self.logger
    @logger ||= Logger.new(STDOUT)
  end

  def self.config
    @config ||= begin
      CONFIG_PATHS.each do |path|
        if File.file?(path)
          return Config.new(YAML.load_file(path))
        end
      end
      Config.new
    end
  end

end
