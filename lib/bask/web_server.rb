require 'bask'
require 'bask/request'

require 'socket'
require 'thread'
require 'timeout'

module Bask
  class WebServer

    def initialize
    end

    def run
      server = TCPServer.new(Bask.config.web_server_bind_address, Bask.config.web_server_bind_port)
      listen(server)
      Bask.logger.info "Listening on #{Bask.config.web_server_bind_address}:#{Bask.config.web_server_bind_port}"

      while Thread.list.size > 1
        sleep 1
      end
    end

    def listen(server_socket)
      Thread.new(server_socket) do |server|
        loop do
          client = nil
          ios = select([server], nil, nil, 1)
          if ios
            begin
              client = server.accept_nonblock
            rescue IO::WaitReadable, Errno::EINTR
              # Never mind, guess the client went away
            end
          end

          if client
            Thread.new(client) do |c|
              handle_client(c)
            end.tap { |t| t.abort_on_exception = true }
          end
        end
      end.tap { |t| t.abort_on_exception = true }
    end

    def handle_client(socket)
      request = Request.new
      request.socket = socket
      request.remote_ip = socket.peeraddr[3].sub('::ffff:', '')

      Bask.logger.debug "New connection from #{request.remote_ip}"

      Timeout.timeout(5) do
        loop do
          line = socket.gets.to_s
          if line =~ /^Host\:\s*(.*)\r\n/i
            request.host = $1
          elsif line =~ /^\r\n/
            request.headers << "X-Forwarded-For: #{request.remote_ip}\r\n"
            request.headers << "\r\n"
            break
          end
          request.headers << line
        end
      end

      request.handler.handle
    rescue Timeout::Error
      Bask.logger.info "Timeout"
    rescue => e
      Bask.logger.info "Something went wrong: #{e.class.to_s}: #{e.message}"
      e.backtrace.each { |l| Bask.logger.info l }
    ensure
      socket.close rescue nil
    end

  end
end
