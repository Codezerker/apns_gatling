require 'openssl'
require 'http/2'
require 'socket'

module ApnsGatling
  APPLE_DEVELOPMENT_SERVER = "api.development.push.apple.com"
  APPLE_PRODUCTION_SERVER = "api.push.apple.com"

  class Client
    DRAFT = 'h2'.freeze

    attr_reader :connection, :token_maker, :token, :sandbox

    def initialize(team_id, auth_key_id, ecdsa_key, sandbox = false)
      @token_maker = Token.new(team_id, auth_key_id, ecdsa_key)
      @sandbox = sandbox
      @mutex = Mutex.new
      @cv = ConditionVariable.new
      init_vars
    end

    def init_vars
      @mutex.synchronize do 
        @socket.close if @socket && !@socket.closed?
        @socket = nil
        @socket_thread = nil
        @first_data_sent = false
        @token_generated_at = 0
        @blocking = true
      end
    end

    def provider_token
      timestamp = Time.new.to_i
      if timestamp - @token_generated_at > 3550
        @mutex.synchronize do 
          @token_generated_at = timestamp
          @token = @token_maker.new_token
        end
        @token
      else
        @token
      end
    end

    def host
      if sandbox
        APPLE_DEVELOPMENT_SERVER
      else
        APPLE_PRODUCTION_SERVER
      end
    end

    # push message
    def push(message)
      request = Request.new(message, provider_token, host)
      response = Response.new
      ensure_socket_open

      begin
        stream = connection.new_stream
      rescue StandardError => e
        close
        raise e
      end

      stream.on(:close) do
        @mutex.synchronize do 
          @token_generated_at = 0 if response.status == '403' && response.error[:reason] == 'ExpiredProviderToken' 
          if @blocking 
            @blocking = false
            @cv.signal
          end
        end
        yield response
      end

      stream.on(:headers) do |h|
        hs = Hash[*h.flatten]
        response.headers.merge!(hs)
      end

      stream.on(:data) do |d|
        response.data << d
      end

      stream.headers(request.headers, end_stream: false)
      stream.data(request.data)
      @mutex.synchronize { @cv.wait(@mutex, 60) } if @blocking
    end
    
    # connection
    def connection
      @connection ||= HTTP2::Client.new.tap do |conn|
        conn.on(:frame) do |bytes|
          @mutex.synchronize do
            @socket.write bytes
            @socket.flush
            @first_data_sent = true
          end
        end
      end
    end

    # scoket 
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
      ctx = OpenSSL::SSL::SSLContext.new
      ctx.verify_mode = OpenSSL::SSL::VERIFY_NONE

      # For ALPN support, Ruby >= 2.3 and OpenSSL >= 1.0.2 are required
      ctx.alpn_protocols = [DRAFT]
      ctx.alpn_select_cb = lambda do |protocols|
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

    def ensure_sent_before_receiving
      while !@first_data_sent
        sleep 0.01
      end
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

    def close
      exit_thread(@socket_thread)
      init_vars
    end

    def exit_thread(thread)
      return unless thread
      thread.exit
      thread.join
    end

    def join
      @socket_thread.join if @socket_thread
    end
  end
end

