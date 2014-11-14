require 'socialinvestigator/client/net'

module Socialinvestigator
  module CLI
    class Net < Thor
      desc "page_info URL", "Looks at a page to see what social links it finds"
      def page_info( url )
        knowledge = client.get_knowledge( url )
        knowledge.print
      end

      desc "get_apps_json", "Download the apps.json file form Wappalyzer"
      def get_apps_json
        puts "Loading from https://raw.githubusercontent.com/ElbertF/Wappalyzer/master/share/apps.json"
        json_data = HTTParty.get "https://raw.githubusercontent.com/ElbertF/Wappalyzer/master/share/apps.json"
        Socialinvestigator::Config.config.apps_json= json_data
        puts "Saved"
      end


      private
      def client
        @client ||= Socialinvestigator::Client::NetClient.new
      end
    end
  end
end