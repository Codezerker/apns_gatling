require 'apns_gatling'
require 'openssl'

team_id = '<Your team id>'
auth_key_id = '<Your Dev auth p8 file key>'
auth_key_file = '<Your Dev auth p8 file>'
ecdsa_key = OpenSSL::PKey::EC.new File.read auth_key_file

def message(body)
  msg = ApnsGatling::Message.new '<device token>'
  msg.alert = {title: "test", body: body}
  msg.topic = '<Your App Bundle ID>'
  msg
end

client = ApnsGatling::Client.new team_id, auth_key_id, ecdsa_key, true

6.times do |i|
  puts "num #{i}"
  client.push(message("test #{i}")) do |r|
    puts "num #{i} success: #{r.ok?}, error: #{r.error}"
  end
end

client.join
