require 'twitter'

class User
  attr_accessor :screenname, :name, :token, :secret
  def initialize( screenname, attrs )
    @screenname = screenname
    @name = attrs['name']
    @token = attrs['token']
    @secret = attrs['secret']
  end

  def self.load screenname
    return nil if screenname.nil? || screenname == ""
    User.new( screenname, REDIS.hgetall( "user:#{screenname}" ))
  end

  def update
    self.update @screenname, @name, @token, @secret
  end

  def self.update screenname, name, token, secret
    key = "user:#{screenname}"
    REDIS.pipelined do
      REDIS.sadd "users", key

      REDIS.hmset key, "name", name
      REDIS.hmset key, "token", token
      REDIS.hmset key, "secret", secret
    end
  end

  def twitter_client
    @twitter_client ||= Twitter::REST::Client.new do |config|
        config.consumer_key       = ENV['CONSUMER_KEY']
        config.consumer_secret    = ENV['CONSUMER_SECRET']
        config.oauth_token        = self.token # ENV['OAUTH_TOKEN']
        config.oauth_token_secret = self.secret # ENV['OAUTH_TOKEN_SECRET']
    end
  end
end