require 'socialinvestigator/client/net'

module Socialinvestigator
  module CLI
    class Net < Thor
      desc "page_info URL", "Looks at a page to see what social links it finds"
      options [:noreverse, :debug]
      long_desc <<-PAGE_INFO
      page_info URL

      Looks at a page to see what social links it finds

      --noreverse skips the reverse ip lookup and associate whois call
      --debug prints out every fact that is discovered
      PAGE_INFO
      def page_info( url )
        knowledge = client.get_knowledge( url, options[:noreverse], options[:debug] )
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