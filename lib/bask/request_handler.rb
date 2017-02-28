module Bask
  class RequestHandler

    def initialize(request)
      @request = request
    end

    def handle

      if @request.app.nil?
        @request.render(404, "No application found for this host (#{@request.host})")
        return
      end

      unless @request.app.ready?
        @request.render(503, "The backend app isn't ready for connections. Have you started it?")
        return
      end

      backend_socket = nil
      begin
        Timeout.timeout(5) do
          backend_socket = TCPSocket.new('127.0.0.1', @request.app.port)
        end
        backend_socket.write(@request.headers)
      rescue Errno::ECONNREFUSED, Errno::ENETUNREACH, Errno::EHOSTUNREACH, Errno::ETIMEDOUT => e
        # This is a 503 error.
        @request.render(503, "Couldn't connect to backend at 127.0.0.1:#{@request.app.port}")
        Bask.logger.debug "Couldn't connect to backend at 127.0.0.1:#{@request.app.port}"
        backend_socket.close rescue nil
        return
      rescue Timeout::Error => e
        # This is a timeout. Highly unlikely.
        @request.render(503, "Timeout connecting to backend")
        Bask.logger.debug "Time out connecting to backend"
        backend_socket.close rescue nil
        return
      rescue => e
        Bask.logger.error "Error: #{e.class} (#{e.message}"
        backend_socket.close rescue nil
        return
      end

      begin
        socks = [@request.socket, backend_socket]
        activity_counter = 0
        loop do
          if ios = IO.select(socks, nil, nil, 1)
            activity_counter = 0
            ios.first.each do |io|
              other_io = backend_socket == io ? @request.socket : backend_socket
              other_io.write(io.readpartial(1024))
            end
          else
            activity_counter += 1
            if activity_counter >= 60
              raise Timeout::Error
            end
          end
        end
      rescue EOFError, Errno::EPIPE, Errno::ECONNRESET => e
        Bask.logger.debug "Connection closed by someone"
      rescue Timeout::Error => e
        Bask.logger.debug "Timeout while waiting for data"
      ensure
        backend_socket.close rescue nil
      end
    end

  end
end