require 'twitter'
require 'socialinvestigator/client/twitter'

module Socialinvestigator
  module CLI
    class TwitterCli < Thor
      desc "user SCREENAME", "Look up info for a specific user."
      def user( username )
        agent.print_user_info client.user( "wschenk" )
      end

      desc "lookup URL", "Resolve a link"
      def lookup( url )
        puts agent.lookup_url( url )
      end

      desc "user_timeline", "Show the authenticated user's tweets"
      def user_timeline
        client.user_timeline.each do |tweet|
          puts "@#{tweet.user.user_name}:#{tweet.text}"
        end
      end

      desc "home_timeline", "Show the authenticated user's timeline"
      def home_timeline
        client.home_timeline.each do |tweet|
          puts "@#{tweet.user.user_name}:#{tweet.text}"
        end
      end

      desc "retweets", "Show the authenticated user's retweets"
      def retweets
        client.retweets_of_me.each do |tweet|
          puts "@#{tweet.user.user_name}:#{tweet.text}"
        end
      end

      desc "mentions", "Show the authenticated user's mentions"
      def mentions
        client.mentions.each do |tweet|
          puts "@#{tweet.user.user_name}:#{tweet.text}"
        end
      end

      desc "limits", "Print out the current rate limits"
      def limits
        resp = client.get( "/1.1/application/rate_limit_status.json" )
        current_time = Time.now.to_i
        template = "   %-40s %5d remaining, resets in %3d seconds\n"
        resp.body[:resources].each do |category,resources|
          puts category.to_s
          resources.each do |resource,info|
            printf template, resource.to_s, info[:remaining], (info[:reset] - current_time)
          end
        end
      end

      desc "followers SCREENNAME", "Prints out all of the users followers"
      def followers( screenname )
        client.followers( screenname ).each do |u|
          printf( "@%-15s %-20s %s\n", u.user_name, u.name, u.description )
        end
      end

      desc "search STRING", "Shows all the tweets that match the string"
      options [:exact, :user_info]
      def search( string )
        string = "\"#{string}\"" if options[:exact]
        reach = 0
        client.search( string, count: 100 ).each do |t|
          puts "#{t.id}:#{t.created_at}:@#{t.user.user_name}:#{t.user.followers_count}:#{t.retweet_count}:#{t.text}"
          reach += t.user.followers_count
          if options[:user_info]
            agent.print_user_info t.user if options[:user_info]
            puts
          end
        end
        puts "#{string} reached #{reach} people."
      end

      desc "filter TERMS", "Print out tweets that match the terms"
      def filter( terms )
        streaming_client.filter(track: terms) do |object|
          puts "@#{object.user.user_name}:#{object.text}" if object.is_a?(Twitter::Tweet)
        end
      end

      desc "listen", "Prints our the authenticated user's stream as it happens"
      def listen
        streaming_client.user do |object|
          case object
          when Twitter::Tweet
            puts "Tweet:@#{object.user.user_name}:#{object.text}"
          when Twitter::DirectMessage
            puts "DM:@#{object.sender.user_name}:#{object.text}"
          when Twitter::Streaming::StallWarning
            warn "Falling behind!"
          end
        end
      end

      desc "config", "Prompts for the authnetication settings"
      def config
        config = Socialinvestigator::Config.config.twitter_config || {}
        print "App key            : "
        config[:twitter_app_key] = $stdin.gets.strip
        print "App Secret         : "
        config[:twitter_app_secret] = $stdin.gets.strip
        print "Access token       : "
        config[:twitter_access_token] = $stdin.gets.strip
        print "Access token secret: "
        config[:twitter_access_token_secret] = $stdin.gets.strip
        Socialinvestigator::Config.config.twitter_config = config
        puts "Saved."
      end

      private
      def agent
        @agent ||= Socialinvestigator::Client::Twitter.new
      end

      def client
        tc = Socialinvestigator::Config.config.twitter_config
        if tc.nil? || tc[:twitter_app_key].nil?
          puts "Twitter config not found, try running:"
          puts "socialinvestigator twitter config"
          exit
        end
        @client ||= ::Twitter::REST::Client.new do |config|
          config.consumer_key        = tc[:twitter_app_key]
          config.consumer_secret     = tc[:twitter_app_secret]
          config.access_token        = tc[:twitter_access_token]
          config.access_token_secret = tc[:twitter_access_token_secret]
        end
      end

      def streaming_client
        tc = Socialinvestigator::Config.config.twitter_config
        if tc.nil?
          puts "Twitter config not found, try running:"
          puts "socialinvestigator twitter config"
          exit
        end
        @streaming_client ||= ::Twitter::Streaming::Client.new do |config|
          config.consumer_key        = tc[:twitter_app_key]
          config.consumer_secret     = tc[:twitter_app_secret]
          config.access_token        = tc[:twitter_access_token]
          config.access_token_secret = tc[:twitter_access_token_secret]
        end
      end
    end
  end
end