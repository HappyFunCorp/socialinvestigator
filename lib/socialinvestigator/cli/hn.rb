require 'socialinvestigator/client/hn'

module Socialinvestigator
  module CLI
    class Hn < Thor
      desc "search URL", "Search hn.algolia.com for a url mentioned on Hackernews"
      option :tags
      def search( url )
        result = client.search_by_date( url, options[:tag] ).parsed_response

        puts "#{result['nbHits']} Hits"

        result['hits'].each do |hit|
          puts "#{hit['title']}#{hit['story_title']}"
          puts "  #{hit['url']}" if hit['url'] != ""
          puts "  #{hit['points']} points"
          puts "  #{hit['num_comments']} comments" if hit['num_comments']
          puts "  https://news.ycombinator.com/item?id=#{hit['objectID']}"
          puts
        end
      end

      private
      def client
        @client ||= Socialinvestigator::Client::Hn.new
      end
    end
  end
end
