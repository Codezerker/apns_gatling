require 'openssl'
require 'http/2'

module ApnsGatling
  APPLE_DEVELOPMENT_SERVER = "api.development.push.apple.com"
  APPLE_PRODUCTION_SERVER = "api.push.apple.com"

  class Client
    attr_reader :connection, :token_maker, :token, :sandbox

    def initialize(team_id, auth_key_id, ecdsa_key, sandbox = false)
      @token_maker = Token.new(team_id, auth_key_id, ecdsa_key)
      @connection = HTTP2::Client.new
      @sandbox = sandbox
    end

    def update_token()
      @token = token_maker.new_token
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
      # TODO:
    end
    # TODO: regenerate auth token
  end
end
