require 'twitter'

require_relative 'lib/config'
require_relative 'lib/models'
require 'pp'

si_user = User.load "SoInvNet"

if si_user.token.nil? || si_user.token == ""
  puts "Go to /login/dm and login with the SoInvNet user!"
  exit 1
end

client = Twitter::REST::Client.new do |config|
  config.consumer_key       = ENV['CONSUMER_KEY']
  config.consumer_secret    = ENV['CONSUMER_SECRET']
  config.oauth_token        = si_user.token # ENV['OAUTH_TOKEN']
  config.oauth_token_secret = si_user.secret # ENV['OAUTH_TOKEN_SECRET']
  # config.auth_method = :oauth
end

pp client
dms = client.direct_messages_received
puts dms.size
dms.each do |m|
  pp m.text
  pp m.sender

  client.create_direct_message m.sender, "echo #{m.text}"
end