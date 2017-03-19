require 'bask/app'

module Bask
  class Config

    attr_reader :path

    def initialize(path)
      @path = path
      load
    end

    def pid_path
      File.join('', 'tmp', 'bask.pid')
    end

    def log_path
      File.join('', 'tmp', 'bask.log')
    end

    def web_server
      @config['web_server'] || {}
    end

    def web_server_bind_address
      web_server['bind_address'] || '0.0.0.0'
    end

    def web_server_bind_port
      web_server['bind_port'] || 80
    end

    def dns_server
      @config['dns_server'] || {}
    end

    def dns_server_bind_port
      dns_server['bind_port'] || 5454
    end

    def apps
      @apps ||= begin
        if @config['apps']
          @config['apps'].each_with_object({}) do |(name, options), hash|
            hash[name] = App.new(name, options)
          end
        else
          {}
        end
      end
    end

    def add_app(name, properties)
      @config['apps'][name] = properties
      save
    end

    def remove_app(name)
      @config['apps'].delete(name)
      save
    end

    def load
      @config = YAML.load_file(@path)
    end

    def save
      File.open(@path, 'w') { |f| f.write(@config.to_yaml) }
    end

    def reload
      load
      apps.each { |name, app| app.reload(@config['apps'][name]) }
    end

  end
end
