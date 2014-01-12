require 'twitter'
require 'pp'

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

class Task
  class << self; attr_accessor :queue_name end
  @queue_name = self.name
  @@queues = {}

  # Queue methods

  def self.process_queues
    Task.queues.collect do |queue_name,qclazz|
      Thread.start do
        qclazz.process( new_redis )
      end
    end.each(&:join)
  end

  def self.process( redis )
    while true
      puts "#{@queue_name}:Waiting"
      queue_status "status", "waiting"
      queue_status "job", ""
      key = redis.blpop @queue_name
      queue_status "status", "running"
      queue_status "job", key[1]
      task = queues[key[0]].load key[1]
      task.redis = redis
      if task.status == "queued" && task.queued_too_long?
        task.status = "shed"
      else
        task.status = "processing"
        if task.process
          task.status = "loaded"
        end
      end
      # task.notify_watchers
    end
  end

  def self.my_queue name
    self.queue_name = name
    Task.queues[queue_name] = self
  end

  def self.queues
    @@queues
  end

  def self.load key
    new(@queue_name,key)
  end

  def self.queue_status status, value
    puts "self #{@queue_name}:status #{status} #{value}"
    REDIS.hmset "#{@queue_name}:status", status, value
  end

  def queue_status status, value
    puts "     #{@queue_name}:status #{status} #{value}"
    redis.hmset "#{@queue_name}:status", status, value
  end

  # Task Methods
  attr_accessor :name,:key,:redis

  def initialize(queue_name, key)
    @name = "task:#{queue_name}:#{key}"
    @queue_name = queue_name
    @key = key
    @attrs = REDIS.hgetall @name
  end

  def redis
    @redis || REDIS
  end

  def status= status
    redis.hmset name, "status", status
    redis.hmset name, "status_updated", Time.now
    if status == "loaded"
      redis.hmset name, "last_loaded", Time.now
    end
    @attrs['status'] = status
  end

  def status
    @attrs["status"]
  end

  def user= user
    redis.hmset name, "user", user
    @attrs['user'] = user
  end

  def user
    @attrs["user"]
  end

  def last_loaded
    return Time.parse @attrs['last_loaded'] if @attrs['last_loaded']
    nil
  end

  def queued_at
    return Time.parse @attrs['queued_at'] if @attrs['queued_at']
    nil
  end

  def queued_too_long?
    return true if queued_at.nil?
    (queued_at||0).to_i > Time.now.to_i + 60*60*1 # 1 hour
  end

  def stale?
    if status == "queued" || status == "processing"
      return true if Time.now.to_i > (queued_at||0).to_i + 60*30 # 3 Minutes
    end

    return true if status != "loaded" && status != "processing" && status != "queued"

    if status == "loaded"
      return true if Time.now.to_i > (last_loaded||0).to_i + 60*60*1 # 1 hour
    end

    false
  end

  def self.ensure key, user=nil
    task = load(key)
    task.user = user

    if task.stale?
      if task.status != "queued"
        queue! task
      end
    end
    task.status
  end

  def self.data key, user=nil
    self.ensure key, user

    task = load(key)
    { status: task.status, data: task.data}
  end

  def data
    []
  end

  def self.queue! task
    task.log "Queueing the task:#{task.name} on #{queue_name}"
    REDIS.hmset task.name, "queued_at", Time.now
    REDIS.rpush queue_name, task.key
    task.status = "queued"
  end

  def self.requeue key, user=nil
    task = load key
    task.user = user
    queue! task
    task.status
  end

  def log string
    puts "#{@name}:#{string}"
  end

  def process
    log "Processing #{@key}"
    true
  end
end

class TwitterTask < Task
  def client
    if @client.nil?
      log "Creating rest client for user #{user}..."

      ti_user = User.load user
      pp ti_user
      @client = Twitter::REST::Client.new do |config|
        config.consumer_key       = ENV['CONSUMER_KEY']
        config.consumer_secret    = ENV['CONSUMER_SECRET']
        config.oauth_token        = ti_user.token # ENV['OAUTH_TOKEN']
        config.oauth_token_secret = ti_user.secret # ENV['OAUTH_TOKEN_SECRET']
      end
    end

    @client
  end

  def handle_too_many_requests
    retry_count = 0
    begin
      ret = yield
    rescue Twitter::Error::TooManyRequests => error
      retry_count += 1
      log "Got TooManyRequests #{retry_count}"
      if retry_count > 5
        raise
      else
        status="paused"
        log "Hit rate limit, sleeping for #{error.rate_limit.reset_in}..."
        queue_status "reset_at", error.rate_limit.reset_at
        queue_status "status", "paused"
        redis.rpush @queue_name, key
        sleep error.rate_limit.reset_in
        queue_status "status", "in_job"
        queue_status "reset_at", ""
        status="processing"
        retry
      end
    end
  end
end

class FriendsTask < TwitterTask
  my_queue "friends"

  def process
    twitter_username = key
    log "Pulling in friends for #{twitter_username}"
    cursor = -1
    while (cursor != 0) do
      handle_too_many_requests do 
        friends = client.friends(twitter_username, {:cursor => cursor, :count => 200} )
        running_count = 0
        friends.each do |f|
          redis.sadd "friends:#{key}", f.screen_name
          running_count += 1
          # myfile.puts "\"#{running_count}\",\"#{f.name.gsub('"','\"')}\",\"#{f.screen_name}\",\"#{f.url}\",\"#{f.followers_count}\",\"#{f.location.gsub('"','\"').gsub(/[\n\r]/," ")}\",\"#{f.created_at}\",\"#{f.description.gsub('"','\"').gsub(/[\n\r]/," ")}\",\"#{f.lang}\",\"#{f.time_zone}\",\"#{f.verified}\",\"#{f.profile_image_url}\",\"#{f.website}\",\"#{f.statuses_count}\",\"#{f.profile_background_image_url}\",\"#{f.profile_banner_url}\""
        end
        log "#{running_count} loaded"
        cursor = friends.attrs[:next_cursor] #next_cursor
        break if cursor == 0
      end
    end

    log "Done"
    true
  end

  def data
    redis.smembers( "friends:#{key}" ).sort
  end
end

class TimelineTask < TwitterTask
  my_queue "timelines"

  def process
    log "Starting timeline task"
    earliest = Time.now.to_i - 6*30*24*60*60

    max_id = 0
    new_tweets = 1
    added = true
    while new_tweets > 0 && added
      log "new_tweets:#{new_tweets}"
      new_tweets = 0
      added = false
      handle_too_many_requests do
        # log "inside handle_too_many_requests"
        options={}
        options[:screen_name] = key
        options[:count] = 200
        options[:max_id] = max_id if max_id != 0
        # log "Printing options"
        pp options
        tweets = client.user_timeline options
        new_tweets = tweets.size
        log "Got #{new_tweets} tweets"
        tweets.each do |tweet|
          if tweet.created_at.to_i > earliest
            added = redis.sadd( "tweets:#{key}", tweet.id ) || added
            redis.hmset "tweet:#{tweet.id}", "text", tweet.text
            redis.hmset "tweet:#{tweet.id}", "created_at", tweet.created_at
            max_id = tweet.id - 1
          else
            # log "Skipping old tweets"
            added = false
          end
        end
      end
    end

    log "Finished loading #{key}'s timeline"
    true
  end

  def data
    earliest = Time.now.to_i - 6*30*24*60*60

    redis.smembers( "tweets:#{key}" ).collect do |id|
      redis.hgetall "tweet:#{id}"
    end.select do |x|
      x['created_at'] = Time.parse x['created_at']
      x['created_at'].to_i > earliest
    end.sort do |b,a|
      a['created_at'].to_i <=> b['created_at'].to_i
    end
  end
end