require 'bask/app'

module Bask
  class Config

    def initialize(config = {})
      @config = config
    end

    def bind_address
      @config['bind_address'] || '0.0.0.0'
    end

    def bind_port
      @config['bind_port'] || 8080
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

  end
end
