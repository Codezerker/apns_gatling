require 'openssl'
require 'http/2'
require 'socket'

module ApnsGatling
  APPLE_DEVELOPMENT_SERVER = "api.development.push.apple.com"
  APPLE_PRODUCTION_SERVER = "api.push.apple.com"

  class Client
    DRAFT = 'h2'.freeze

    attr_reader :connection, :token_maker, :token, :sandbox, :socket_thread
    attr_writer :socket

    def initialize(team_id, auth_key_id, ecdsa_key, sandbox = false)
      @token_maker = Token.new(team_id, auth_key_id, ecdsa_key)
      @sandbox = sandbox
      @mutex = Mutex.new
    end

    def init_vars
      @mutex.synchronize do 
        @socket.close if @socket && !@socket.closed?
        @socket = nil
        @socket_thread = nil
        @first_data_sent = false
      end
    end

    def connection
      @connection ||= HTTP2::Client.new.tap do |conn|
        conn.on(:frame) do |bytes|
          puts "Sending bytes: #{bytes.unpack("H*").first}"
          @mutex.synchronize do
            @socket.write bytes
            @socket.flush
            @first_data_sent = true
          end
        end

        conn.on(:frame_sent) do |frame|
          puts "Sent frame: #{frame.inspect}"
        end

        conn.on(:promise) do |promise|
          promise.on(:headers) do |h|
            puts "promise headers: #{h}"
          end

          promise.on(:data) do |d|
            log.info "promise data chunk: <<#{d.size}>>"
          end
        end

        conn.on(:frame_received) do |frame|
          puts "Received frame: #{frame.inspect}"
        end

        conn.on(:altsvc) do |f|
          puts "received ALTSVC #{f}"
        end
      end
    end

    def ensure_socket_open
      @mutex.synchronize do 
        return if @socket_thread
        @socket = new_socket
        @socket_thread = Thread.new do 
          begin 
            socket_loop
          rescue EOFError
            init_vars
            raise SocketError.new('Socket was remotely closed')
          rescue Exception => e
            init_vars
            raise e
          end
        end.tap { |t| t.abort_on_exception = true }
      end
    end

    def new_socket
      puts ">>>> new scoket <<<<"
      ctx = OpenSSL::SSL::SSLContext.new
      ctx.verify_mode = OpenSSL::SSL::VERIFY_NONE

      # For ALPN support, Ruby >= 2.3 and OpenSSL >= 1.0.2 are required
      ctx.alpn_protocols = [DRAFT]
      ctx.alpn_select_cb = lambda do |protocols|
        puts "ALPN protocols supported by server: #{protocols}"
        DRAFT if protocols.include? DRAFT
      end

      tcp = TCPSocket.new(host, 443)
      socket = OpenSSL::SSL::SSLSocket.new(tcp, ctx)
      socket.sync_close = true
      socket.hostname = host
      socket.connect

      if socket.alpn_protocol != DRAFT
        puts "Failed to negotiate #{DRAFT} via ALPN"
        exit
      end
      socket
    end

    def socket_loop
      ensure_sent_before_receiving
      loop do
        begin
          data = @socket.read_nonblock(1024)
          connection << data # in
        rescue IO::WaitReadable
          IO.select([@socket])
          retry
        rescue IO::WaitWritable
          IO.select(nil, [@socket])
          retry
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

    def ensure_sent_before_receiving
      while !@first_data_sent
        sleep 0.01
      end
    end

    def push(message)
      update_token unless @token
      request = Request.new(message, @token, host)
      response = Response.new
      ensure_socket_open

      begin
        stream = connection.new_stream
        puts "stream id: #{stream.id}"
      rescue StandardError => e
        close
        raise e
      end

      stream.on(:close) do
        yield response
      end

      stream.on(:half_close) do
        puts "closing client-end of the stream"
      end

      stream.on(:headers) do |h|
        hs = Hash[*h.flatten]
        response.headers.merge!(hs)
      end

      stream.on(:data) do |d|
        response.data << d
      end

      stream.on(:altsvc) do |f|
        puts "received ALTSVC #{f}"
      end

      stream.headers(request.headers, end_stream: false)
      stream.data(request.data)
    end
    
    def close
      exit_thread(@socket_thread)
      init_vars
    end

    def exit_thread(thread)
      return unless thread
      thread.exit
      thread.join
    end
  end
end

