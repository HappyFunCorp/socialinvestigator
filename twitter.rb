require 'twitter'

require_relative 'lib/config'
require_relative 'lib/models'
require 'pp'

si_user = User.load "SoInvNet"
pp si_user
client = Twitter::REST::Client.new do |config|
  config.consumer_key       = ENV['CONSUMER_KEY']
  config.consumer_secret    = ENV['CONSUMER_SECRET']
  config.oauth_token        = si_user.token # ENV['OAUTH_TOKEN']
  config.oauth_token_secret = si_user.secret # ENV['OAUTH_TOKEN_SECRET']
  # config.auth_method = :oauth
end

pp client
pp client.direct_messages