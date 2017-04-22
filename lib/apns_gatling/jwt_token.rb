require 'jwt'

module ApnsGatling
  class Token
    attr_reader :team_id, :auth_key_id, :ecdsa_key

    def initialize(team_id, auth_key_id, ecdsa_key)
      @team_id = team_id
      @auth_key_id = auth_key_id
      @ecdsa_key = ecdsa_key
    end

    def new_token
      payload = {iss: @team_id, iat: Time.now.to_i}
      header = {kid: @auth_key_id}
      JWT.encode payload, @ecdsa_key, 'ES256', header
    end
  end
end
