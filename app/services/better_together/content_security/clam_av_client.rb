# frozen_string_literal: true

require 'socket'
require 'timeout'

module BetterTogether
  module ContentSecurity
    # TCP client for the ClamAV INSTREAM protocol.
    class ClamAvClient
      class Error < StandardError; end
      class ConnectionError < Error; end

      def initialize(host:, port:, timeout:, max_stream_bytes:)
        @host = host
        @port = port
        @timeout = timeout
        @max_stream_bytes = max_stream_bytes
      end

      def scan_file(path)
        size = File.size(path)
        raise Error, "File exceeds ClamAV stream limit (#{size} > #{@max_stream_bytes})" if size > @max_stream_bytes

        response = nil
        Socket.tcp(@host, @port, connect_timeout: @timeout) do |socket|
          stream_file_to_socket(socket, path)
          response = read_response(socket)
        end
        parse_response(response)
      rescue Timeout::Error, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ETIMEDOUT, SocketError => e
        raise ConnectionError, e.message
      end

      private

      def stream_file_to_socket(socket, path)
        # Timeout covers streaming, not just connect — clamd dying mid-scan would otherwise
        # block socket.write indefinitely since connect_timeout only applies to handshake.
        Timeout.timeout(@timeout) do
          socket.write("zINSTREAM\0")
          File.open(path, 'rb') do |file|
            while (chunk = file.read(8192))
              socket.write([chunk.bytesize].pack('N'))
              socket.write(chunk)
            end
          end
          socket.write([0].pack('N'))
        end
      end

      def read_response(socket)
        buffer = +''

        Timeout.timeout(@timeout) do
          loop do
            buffer << socket.readpartial(1024)
            break if buffer.include?("\0")
          end
        end

        buffer.delete("\0").strip
      end

      def parse_response(response)
        return { status: :clean, signature_name: nil, raw_response: response } if response.end_with?('OK')

        if response.include?('FOUND')
          signature_name = response.split(':', 2).last.to_s.sub('FOUND', '').strip
          return { status: :infected, signature_name:, raw_response: response }
        end

        raise Error, response
      end
    end
  end
end
