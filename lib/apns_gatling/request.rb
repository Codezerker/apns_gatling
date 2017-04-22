module ApnsGatling
  class Request
    attr_reader :path, :headers, :body

    def initialize(message)
      @path = "/3/device/#{message.token}"
      @headers = headers_from message
      @body = message.body
    end

    private
    def headers_from(message)
      headers = {}
      headers.merge!('apns-id' => message.apns_id) if message.apns_id
      headers.merge!('apns-expiration' => message.expiration.to_s) if message.expiration
      headers.merge!('apns-priority' => message.priority.to_s) if message.priority
      headers.merge!('apns-topic' => message.topic) if message.topic
      headers.merge!('apns-collapse-id' => message.apns_collapse_id) if message.apns_collapse_id
      headers
    end
  end
end
