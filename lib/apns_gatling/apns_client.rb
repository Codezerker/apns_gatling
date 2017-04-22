require 'openssl'
require 'http/2'

module ApnsGatling
  APPLE_DEVELOPMENT_SERVER = "api.development.push.apple.com"
  APPLE_PRODUCTION_SERVER = "api.push.apple.com"

  class Client
    attr_reader :client, :token_maker

    def initialize(team_id, auth_key_id, ecdsa_key)
      @token_maker = ApnsGatling::Token.new(team_id, auth_key_id, ecdsa_key)
      @client = HTTP2::Client.new
    end

    def push(message)
      request = ApnsGatling::Request.new(message)
      # TODO:
    end
  end
end
