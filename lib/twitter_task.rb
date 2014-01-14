require 'twitter'
require_relative 'task'
require_relative 'user'

class TwitterTask < Task
  def client
    if @client.nil?
      log "Creating rest client for user #{user}..."

      ti_user = User.load user
      # pp ti_user
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
    rescue e
      log e
      raise e
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
    earliest = Time.now.to_i - 12*30*24*60*60 # 1 year

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

class WordcloudTask < TwitterTask
  my_queue "wordcloud"
  
  def process
    log "Starting wordcloud task"

    t = TimelineTask.ensure key, user, @queue_name

    log "Status = #{t}"

    if t != 'loaded'
      log "Timeline task is stale"
      return false
    end

    if t == 'loaded'
      log "Processing wordcloud task"

      task = TimelineTask.load key

      data = task.data

      set = "wordcloud:#{key}"
      redis.del set
      data.each do |tweet|
        words = tweet["text"].gsub( /[\(\)\.,"-:’\|…]*/, "" ).downcase.split.each do |word|
          unless redis.sismember "stopwords", word
            redis.zincrby set, 1, word
          end
        end
      end
    end

    log "Ending wordcloud task"
    true
  end

  def data
    redis.zrevrange "wordcloud:#{key}", 0, 100,  {:with_scores=>true}
    # c.Do("ZREVRANGE", word_key, "0", "50", "WITHSCORES"))
  end
end