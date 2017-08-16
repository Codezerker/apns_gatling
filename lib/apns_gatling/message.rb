require 'json'
require 'securerandom'

module ApnsGatling
  class Message
    # see: https://developer.apple.com/library/content/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/PayloadKeyReference.html#//apple_ref/doc/uid/TP40008194-CH17-SW1
    MAXIMUM_PAYLOAD_SIZE = 4096

    attr_reader :token
    attr_accessor :alert, :badge, :sound, :content_available, :mutable_content, :category, :custom_payload, :thread_id
    attr_accessor :apns_id, :expiration, :priority, :topic, :apns_collapse_id

   def initialize(token)
     @token = token
     @apns_id = SecureRandom.uuid
   end

   def payload_data
     payload.to_json.force_encoding(Encoding::BINARY)
   end

   def valid?
     data.bytesize <= MAXIMUM_PAYLOAD_SIZE
   end

   def payload
     aps = {}

     aps.merge!(alert: alert) if alert
     aps.merge!(badge: badge) if badge
     aps.merge!(sound: sound) if sound
     aps.merge!(category: category) if category
     aps.merge!('content-available' => content_available) if content_available
     aps.merge!('mutable-content' => mutable_content) if mutable_content
     aps.merge!('thread-id' => thread_id) if thread_id

     message = {aps: aps}
     message.merge!(custom_payload) if custom_payload
     message
   end
  end
end
