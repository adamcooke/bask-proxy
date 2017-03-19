require 'socket'

# Inspired by https://gist.github.com/peterc/1425383 by peterc

module Bask
  class DNSServer

    def initialize
    end

    def run
      Socket.udp_server_loop(Bask.config.dns_server_bind_port) do |raw_data, src|
        domain = ''
        raw_data = raw_data.force_encoding('UTF-8')
        if raw_data[2].ord & 120 == 0
          idx = 12
          len = raw_data[idx].ord
          until len == 0
            domain += raw_data[idx + 1, len] + '.'
            idx += len + 1
            len = raw_data[idx].ord
          end
        end

        if domain =~ /\.dev\.\z/
          response = "#{raw_data[0,2]}\x81\x00#{raw_data[4,2] * 2}\x00\x00\x00\x00"
          response += raw_data[12..-1]      # Original question
          response += "\xc0\x0c"            # Pointer to refer to domain name in question
          response += "\x00\x01"            # Reponse type (A)
          response += "\x00\x01"            # Class (IN)
          response += [3600].pack("N")      # TTL (seconds)
          rdata = '127.0.0.1'.split('.').collect(&:to_i).pack("C*")
          response += [rdata.length].pack("n")
          response += rdata
        else
          response = "#{raw_data[0,2]}\x81\x03#{raw_data[4,2]}\x00\x00\x00\x00\x00\x00"
          response += raw_data[12..-1]
        end

        src.reply response
      end
    end

  end
end
