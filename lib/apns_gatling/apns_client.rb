require 'openssl'
require 'http/2'
require 'socket'

module ApnsGatling
  APPLE_DEVELOPMENT_SERVER = "api.development.push.apple.com"
  APPLE_PRODUCTION_SERVER = "api.push.apple.com"

  class Client
    DRAFT = 'h2'.freeze

    attr_reader :connection, :token_maker, :token, :sandbox
    attr_writer :socket
    attr_reader :response_headers, :response_data

    def initialize(team_id, auth_key_id, ecdsa_key, sandbox = false)
      @token_maker = Token.new(team_id, auth_key_id, ecdsa_key)
      @sandbox = sandbox
      @response_data = ''
      @response_headers = {}
    end

    def new_connection()
      if @socket && !@socket.closed?
        @socket.close
      end
      setup_socket
      @connection = HTTP2::Client.new
      @connection.on(:frame) do |bytes|
        puts "Sending bytes: #{bytes.unpack("H*").first}"
        @socket.print bytes # put stream frame to socket and waiting for out
        @socket.flush
      end

      @connection.on(:frame_sent) do |frame|
        puts "Sent frame: #{frame.inspect}"
      end

      @connection.on(:promise) do |promise|
        promise.on(:headers) do |h|
          puts "promise headers: #{h}"
        end

        promise.on(:data) do |d|
          log.info "promise data chunk: <<#{d.size}>>"
        end
      end

      @connection.on(:frame_received) do |frame|
        puts "Received frame: #{frame.inspect}"
      end

      @connection.on(:altsvc) do |f|
        puts "received ALTSVC #{f}"
      end
    end

    def setup_socket()
      ctx = OpenSSL::SSL::SSLContext.new
      ctx.verify_mode = OpenSSL::SSL::VERIFY_NONE

      # For ALPN support, Ruby >= 2.3 and OpenSSL >= 1.0.2 are required
      ctx.alpn_protocols = [DRAFT]
      ctx.alpn_select_cb = lambda do |protocols|
        puts "ALPN protocols supported by server: #{protocols}"
        DRAFT if protocols.include? DRAFT
      end

      tcp = TCPSocket.new(host, 443)
      @socket = OpenSSL::SSL::SSLSocket.new(tcp, ctx)
      @socket.sync_close = true
      @socket.hostname = host
      @socket.connect

      if @socket.alpn_protocol != DRAFT
        puts "Failed to negotiate #{DRAFT} via ALPN"
        exit
      end
    end

    def run()
      while !@socket.closed? && !@socket.eof?
        data = @socket.read_nonblock(1024)
        puts "Received bytes: #{data.unpack("H*").first}"
        begin
          @connection << data # in
        rescue => e
          puts "#{e.class} exception: #{e.message} - closing socket."
          e.backtrace.each { |l| puts "\t" + l }
          @socket.close
        end
      end
    end

    def update_token()
      @token = @token_maker.new_token
    end

    def host
      if sandbox
        APPLE_DEVELOPMENT_SERVER
      else
        APPLE_PRODUCTION_SERVER
      end
    end

    def push(message)
      update_token unless @token
      request = Request.new(message, @token, host)

      stream = @connection.new_stream
      stream.on(:close) do
        response = Response.new(@response_headers, @response_data)
        yield response
      end

      stream.on(:half_close) do
        puts "closing client-end of the stream"
      end

      stream.on(:headers) do |h|
        hs = Hash[*h.flatten]
        @response_headers.merge!(hs)
      end

      stream.on(:data) do |d|
        @response_data << d
      end

      stream.on(:altsvc) do |f|
        puts "received ALTSVC #{f}"
      end

      puts request.headers
      stream.headers(request.headers, end_stream: false)
      stream.data(request.data)
    end
  end
end
