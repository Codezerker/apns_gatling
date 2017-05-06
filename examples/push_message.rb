require 'apns_gatling'
require 'openssl'

team_id = '<your team id>'
auth_key_id = '<your auth key id>'
auth_key_file = '<your p8 file>'
ecdsa_key = OpenSSL::PKey::EC.new File.read auth_key_file

def message(body)
  msg = ApnsGatling::Message.new '<device token>'
  msg.alert = {title: "test", body: body}
  msg.topic = '<app bundle id>'
  msg
end

client = ApnsGatling::Client.new team_id, auth_key_id, ecdsa_key, true

puts "messages on the way..."
client.push(message("test 1")) do |response|
  puts response.ok?, response.error
  if response.ok? 
    6.times do |i|
      puts "num #{i}"
      client.push(message("test #{i}")) do |r|
         puts r.ok?, r.error
      end
    end
  end
end
puts ">>>> Waiting... <<<<"
client.join

