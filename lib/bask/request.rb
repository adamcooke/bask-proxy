require 'bask/request_handler'

module Bask
  class Request

    attr_accessor :socket
    attr_accessor :remote_ip
    attr_accessor :host

    def initialize
    end

    def handler
      @handler ||= RequestHandler.new(self)
    end

    def headers
      @headers ||= ""
    end

    def render(status, body)
      buffer = "HTTP/1.1 #{status} Something went wong\r\n"
      buffer << "Content-Length: #{body.bytesize}\r\n"
      buffer << "Content-Type: text/html\r\n"
      buffer << "\r\n"
      buffer << body
      @socket.write(buffer)
    end

    def app_name
      @app_name ||= begin
        host, port = @host.split(':', 2)
        host.split('.').reverse.drop(1).first
      end
    end

    def app
      Bask.config.apps[app_name]
    end

  end
end
