require 'sinatra/base'
require 'haml'
require 'coffee-script'
require 'sass'
require 'tilt'
require 'rack-cache'
require 'oj'
require "sinatra/reloader"
require 'pp'
# require 'sinatra/twitter-bootstrap'

require_relative 'lib/config'
require_relative 'lib/models'

require 'omniauth-twitter'

class WebApp < Sinatra::Base
  # register Sinatra::Twitter::Bootstrap::Assets

  configure :development do
    register Sinatra::Reloader
  end

  # configure :production do
  #   require 'newrelic_rpm'
  # end

  configure do
    enable :sessions, :logging
  end

  helpers do
    def logged_in?
      !session[:screen_name].nil?
    end

    def current_user
      User.load(session[:screen_name])
    end

    def protected!
      return if authorized?
      headers['WWW-Authenticate'] = 'Basic realm="Restricted Area"'
      halt 401, "Not authorized\n"
    end

    def authorized?
      @auth ||=  Rack::Auth::Basic::Request.new(request.env)
      @auth.provided? and @auth.basic? and @auth.credentials and @auth.credentials == [ENV['AUTH_USER'], ENV['AUTH_PASS']]
    end
  end

  use OmniAuth::Builder do
    provider :twitter, ENV['CONSUMER_KEY'], ENV['CONSUMER_SECRET']
  end

  set :public_folder, 'public'
  set :static_cache_control, [:public, max_age: 60000] # 1000 mins.

  get '/' do
    # cache_control :public, max_age: 600  # 10 mins. #disable until password is gone
    # protected! if ENV['RACK_ENV'] == 'production'
    haml :index
  end

  get '/*.html' do
    haml params[:splat].first.to_sym
  end

  get '/application.js' do
    cache_control :public, max_age: 600  # 10 mins.
    coffee :application
  end

  get '/whoami.json' do
    content_type :json
    { "screen_name" => session[:screen_name] }.to_json
  end

  get '/stats.json' do
    content_type :json
    Task.queues.keys.collect do |k|
      r = REDIS.hgetall("#{k}:status")
      r['count'] = REDIS.llen k
      { k => r }
    end.to_json
  end

  get '/login' do
    session[:access] = :read
    redirect to("/auth/twitter?x_auth_access_type=read")
  end
  
  get '/login/write' do
    session[:access] = :write
    redirect to("/auth/twitter?x_auth_access_type=write")
  end

  get '/login/dm' do
    session[:access] = :dm
    redirect to("/auth/twitter?x_auth_access_type=dm")
  end

  get '/auth/twitter/callback' do
    env['omniauth.auth'] ? session[:admin] = true : halt(401,'Not Authorized')
    "You are now logged in"
    a = env['omniauth.auth']
    User.update a['info']['nickname'], 
                a['info']['name'], 
                a['credentials']['token'],
                a['credentials']['secret']
    session[:screen_name] = a['info']['nickname']
    # pp a
    redirect "/"
  end

  get '/auth/failure' do
    params[:message]
  end

  get '/timeline.json' do
    ret = {}
    if logged_in?
      user = params[:screen_name] || session[:screen_name]
      if params[:force]
        puts "Requeueing..."
        TimelineTask.requeue user, session[:screen_name]
      end

      ret = TimelineTask.data user, session[:screen_name]
    else
      ret[:status] = "not_logged_in"
    end

    content_type :json
    ret.to_json
  end

  get '/friends.json' do
    ret = {}
    if logged_in?
      user = params[:screen_name] || session[:screen_name]
      if params[:force]
        puts "Requeueing..."

        FriendsTask.requeue user, session[:screen_name]
      end
      ret = FriendsTask.data user, session[:screen_name]
    else
      ret[:status] = "not_logged_in"
    end

    content_type :json
    ret.to_json
  end

  get '/words.json' do
    ret = {}
    if logged_in?
      user = params[:screen_name] || session[:screen_name]
      if params[:force]
        puts "Requeueing..."

        TimelineTask.requeue user, session[:screen_name]
      end
      ret = TimelineTask.data user, session[:screen_name]
    else
      ret[:status] = "not_logged_in"
    end

    content_type :json
    ret.to_json
  end
end