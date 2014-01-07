require 'sinatra/base'
require 'slim'
require 'coffee-script'
require 'sass'
require 'tilt'
require 'rack-cache'
require 'oj'
require "sinatra/reloader"
require 'sinatra/twitter-bootstrap'

require_relative 'lib/config'

require 'omniauth-twitter'

class WebApp < Sinatra::Base
  register Sinatra::Twitter::Bootstrap::Assets

  configure :development do
    register Sinatra::Reloader
  end

  # configure :production do
  #   require 'newrelic_rpm'
  # end

  configure do
    enable :sessions
  end

  helpers do
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
    cache_control :public, max_age: 600  # 10 mins. #disable until password is gone
    # protected! if ENV['RACK_ENV'] == 'production'
    slim :index
  end

  get '/stats' do
    REDIS.keys("queue:*")
  end

  get '/login' do
    redirect to("/auth/twitter")
  end

  get '/auth/twitter/callback' do
    env['omniauth.auth'] ? session[:admin] = true : halt(401,'Not Authorized')
    "You are now logged in"
    require 'pp'
    pp env['omniauth.auth']
    redirect "/"
    # "<h1>Hi #{env['omniauth.auth']['info']['name']}!</h1><img src='#{env['omniauth.auth']['info']['image']}'>"
  end

  get '/auth/failure' do
    params[:message]
  end
end