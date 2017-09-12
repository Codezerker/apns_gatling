require 'json'

module ApnsGatling
  class Response
    # See: https://developer.apple.com/library/content/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/CommunicatingwithAPNs.html
    attr_accessor :headers, :data
    attr_reader :message

    def initialize(message)
      @headers = {}
      @data = ''
      @message = message 
      @internal_error = nil
    end

    def status
      @headers[':status'] if @headers
    end

    def ok?
      status == '200'
    end

    def parse_data
      JSON.parse(@data) rescue @data
    end

    def error_with(reason)
      @internal_error = {reason: reason, 'apns-id': @message.apns_id, status: '0'}
    end

    def error
      return @internal_error if @internal_error
      if status != '200'
        e = {}
        e.merge!(status: @headers[':status']) if @headers[':status']
        e.merge!('apns-id' => @headers['apns-id']) if @headers['apns-id']
        data = parse_data
        e.merge!(reason: data['reason']) if data['reason']
        e.merge!(timestamp: data['timestamp']) if data['timestamp']
        e
      end
    end
  end
end
