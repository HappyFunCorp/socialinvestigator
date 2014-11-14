require 'yaml'

module Socialinvestigator
  module Config
    def self.config
      FileConfigStorage.new
    end

    class AbstractConfigStorage
      def twitter_config
        raise "Not implemented in #{self.class.name}"
      end
    end

    class FileConfigStorage < AbstractConfigStorage
      def initialize( dir = nil )
        @dir = dir || "#{ENV['HOME']}/.socialinvestigator"

        FileUtils.mkdir_p @dir
      end

      def twitter_config
        read_yaml( "twitter.yml" )
      end

      def twitter_config= config
        save_yaml( "twitter.yml", config )
      end

      def apps_json
        read_json( "apps.json" )
      end

      def apps_json=( data )
        File.open( "#{@dir}/apps.json", "w" ) do |out|
          out << data
        end
      end

      def read_yaml( name )
        file = "#{@dir}/#{name}"

        if File.exists? file
          return YAML::load_file( file )
        end

        nil
      end

      def save_yaml( name, obj )
        File.open( "#{@dir}/#{name}", "w" ) do |out|
          out.write obj.to_yaml
        end
      end

      def read_json( name )
        file = "#{@dir}/#{name}"

        if File.exists? file
          return JSON.parse( File.read( file ) )
        end

        nil
      end
    end
  end
end

  #     def credential_store
  #       "#{@dir}/oauth2_creds.json"
  #     end

  #     def client_secrets
  #       "#{@dir}/client_secrets.json"
  #     end

  #     def cached_api( api, version )
  #       "#{@dir}/#{api}-#{version}.cache"
  #     end
  #   end
  # end