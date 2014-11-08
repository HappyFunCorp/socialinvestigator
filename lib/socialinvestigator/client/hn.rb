require 'httparty'

module Socialinvestigator
  module Client
    class Hn
      include HTTParty
      base_uri 'https://hn.algolia.com/api/v1/'

      def search_by_date( query, tags = nil )
        params = {query: query }
        params[:tags] = tags if tags
        self.class.get '/search_by_date', { query: params }
      end
    end
  end
end
