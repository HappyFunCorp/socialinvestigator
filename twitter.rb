require 'twitter'

puts "Starting..."
$stdout.sync = true

require_relative 'lib/config'
require_relative 'lib/models'
require 'pp'

USER="SoInvNet"
puts "Loading user info for #{USER}"
si_user = User.load USER

if si_user.token.nil? || si_user.token == ""
  puts "Go to /login/dm and login with the #{USER} user!"
  exit 1
end

puts "Creating stream client..."
stream = Twitter::Streaming::Client.new do |config|
  config.consumer_key       = ENV['CONSUMER_KEY']
  config.consumer_secret    = ENV['CONSUMER_SECRET']
  config.oauth_token        = si_user.token # ENV['OAUTH_TOKEN']
  config.oauth_token_secret = si_user.secret # ENV['OAUTH_TOKEN_SECRET']
  # config.auth_method = :oauth
end

puts "Creating rest client"
client = Twitter::REST::Client.new do |config|
  config.consumer_key       = ENV['CONSUMER_KEY']
  config.consumer_secret    = ENV['CONSUMER_SECRET']
  config.oauth_token        = si_user.token # ENV['OAUTH_TOKEN']
  config.oauth_token_secret = si_user.secret # ENV['OAUTH_TOKEN_SECRET']
  # config.auth_method = :oauth
end

def process_dm( client, dm )
  key = "dms:#{USER}"
  if REDIS.sismember key, dm.id
    puts "Already did something with this direct message: #{dm.text}"
  else
    puts "Process_dm: #{dm.sender.screen_name}:#{dm.text}"
    if dm.sender.screen_name == USER
      puts "From ourselves, ignoring"
    else
      client.create_direct_message dm.sender, "echo #{dm.text}"[0..139]
    end
    REDIS.sadd key, dm.id
  end
end

def process_mention( mention )
end

Thread.new do
  puts "Waiting for timeline"
  while true
    user = REDIS.blpop "timeline"
    puts "Looking for: #{user}"
  end
end

puts "Processing old DMS"
client.direct_messages_received.each { |m| process_dm(client,m) }

puts "Watching the stream"
stream.user do |object|
  case object
  when Twitter::Tweet
    puts "It's a tweet!"
    puts object.text
  when Twitter::DirectMessage
    process_dm( client, object )
  else
    puts "Got a #{object.class}"
  # when Twitter::Streaming::StallWarning
    # warn "Falling behind!"
  end
end
