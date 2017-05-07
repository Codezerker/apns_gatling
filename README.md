# ApnsGatling

ApnsGatling is a token based authenitcation APNs HTTP/2 gem. 
[Communicating with APNs via HTTP2](https://developer.apple.com/library/content/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/CommunicatingwithAPNs.html) is the specification.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'apns_gatling'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install apns_gatling

## Usage

```
require 'apns_gatling'
require 'openssl'

team_id = '<Your team id>'
auth_key_id = '<Your auth key id>'
auth_key_file = '<Your p8 cert file>'
ecdsa_key = OpenSSL::PKey::EC.new File.read auth_key_file

def message(body)
  msg = ApnsGatling::Message.new '<device token>'
  msg.alert = {title: "test", body: body}
  msg.topic = '<Your App bundle ID>'
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
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/Codezerker/apns_gatling.

