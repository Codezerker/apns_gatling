module ApnsGatling
  class Request
    attr_reader :id, :host, :path, :auth_token, :headers, :data

    def initialize(message, auth_token, host)
      path = "/3/device/#{message.token}"
      @id = message.token + message.apns_id
      @path = path
      @auth_token = auth_token
      @headers = headers_from message, auth_token, host, path
      @data = message.payload_data
    end

    private
    def headers_from(message, auth_token, host, path)
      headers = {':scheme' => 'https',
                 ':method' => 'POST',
                 'host' => host,
                 ':path' => path,
                 'authorization' => "bearer #{auth_token}"}
      headers.merge!('apns-id' => message.apns_id) if message.apns_id
      headers.merge!('apns-expiration' => message.expiration.to_s) if message.expiration
      headers.merge!('apqs-priority' => message.priority.to_s) if message.priority
      headers.merge!('apns-topic' => message.topic) if message.topic
      headers.merge!('apns-collapse-id' => message.apns_collapse_id) if message.apns_collapse_id
      headers
    end
  end
end
