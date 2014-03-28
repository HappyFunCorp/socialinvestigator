class Task
  class << self; attr_accessor :queue_name end
  @queue_name = self.name
  @@queues = {}

  # Queue methods

  def self.process_queues
    Task.queues.collect do |queue_name,qclazz|
      Thread.start do
        begin
          qclazz.process( new_redis )
        rescue e
          puts e
        end
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
      # if Time.now.to_i < (task.last_loaded||0).to_i + 60*60*15 # 15 Minutes
      #   task.status="shed"
      # els
      if task.status == "queued" && task.queued_too_long?
        task.status = "shed"
      elsif task.data_fresh_enough?
        task.log "Data fresh, moving along"
        task.status = "loaded"
      else
        task.status = "processing"
        if task.process
          task.status = "loaded"
          task.notify_watchers
        end
      end
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
    # puts "self #{@queue_name}:status #{status} #{value}"
    REDIS.hmset "#{@queue_name}:status", status, value
  end

  def queue_status status, value
    # puts "     #{@queue_name}:status #{status} #{value}"
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
    return Time.parse @attrs['last_loaded'] if @attrs['last_loaded'] && @attrs['last_loaded'] != ""
    nil
  end

  def last_loaded= time
    redis.hmset name, "last_loaded", time
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
      return true if Time.now.to_i > (queued_at||0).to_i + 60*30 # 30 Minutes
    end

    return true if status != "loaded" && status != "processing" && status != "queued"

    if status == "loaded"
      return true if !data_fresh_enough?
    end

    false
  end

  def data_fresh_enough?
    Time.now.to_i < (last_loaded||0).to_i + 60*60*4  # 4 hours
  end

  def add_watcher queue_name
    log "Adding #{queue_name} to #{@name}:watchers"
    redis.sadd "#{@name}:watchers", queue_name
  end

  def notify_watchers
    while watcher = redis.spop( "#{@name}:watchers" ) do
      log "Notifying #{watcher} of #{key}"
      redis.rpush watcher, key
    end
  end

  def self.ensure key, user=nil, watcher=nil
    task = load(key)
    task.user = user
    task.add_watcher watcher if watcher

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
    task.last_loaded = nil
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