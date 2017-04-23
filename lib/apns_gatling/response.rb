require 'json'

module ApnsGatling
  class Response
    # See: https://developer.apple.com/library/content/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/CommunicatingwithAPNs.html
    attr_reader :headers, :data

    def initialize(headers, data)
      @headers = headers
      @data = data
    end

    def status
      @headers[':status'] if @headers
    end

    def ok?
      status == '200'
    end

    def data
      JSON.parse(@data) rescue @data
    end

    def error
      if status != '200'
        e = {}
        e.merge!(status: @headers[':status']) if @headers[':status']
        e.merge!('apns-id' => @headers['apns-id']) if @headers['apns-id']
        e.merge!(reason: @data[:reason]) if @data[:reason]
        e.merge!(timestamp: @data[:timestamp]) if @data[:timestamp]
        e
      end
    end
  end
end
