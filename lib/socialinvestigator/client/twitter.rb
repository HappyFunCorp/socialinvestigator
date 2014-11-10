require 'httparty'

module Socialinvestigator
  module Client
    class Twitter
      def print_user_info( u )
        t = "%-20s: %s\n"
        printf t, "Screenname", u.user_name
        printf t, "Full Name", u.name
        printf t, "Bio", u.description
        printf t, "Website", lookup_url( u.website.to_s )
        printf t, "Joined", u.created_at.strftime( "%Y-%m-%d" )
        printf t, "Location", u.location
        printf t, "Verified", u.verified?
        printf t, "Tweets", u.tweets_count
        printf t, "Followers", u.followers_count
        printf t, "Following", u.friends_count
        printf t, "Favorites count", u.favorites_count
      end

      def lookup_url( url )
        return nil if url.nil? || url == ""
        r = HTTParty.head url, { follow_redirects: false }
        r['location'] || url
      end
    end
  end
end