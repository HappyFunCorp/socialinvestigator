#!/usr/bin/env ruby 
require 'httparty'
require 'nokogiri'
require 'dnsruby'
require 'whois'
require 'whois/record/parser/blank'
require 'whois/record/contact'

module Socialinvestigator
  module Client
    module Net
      class PageKnowledge
        DEBUG = false
        TEMPLATE = "%20s: %s\n"

        def initialize; @knowledge = {} end

        def remember( key, value )
          return if value.nil?
          p key, value if DEBUG

          @knowledge[key] = value
        end

        def another( key, value )
          return if value.nil?
          p key, value if DEBUG

          @knowledge[key] ||= []
          @knowledge[key] << value
          @knowledge[key] = @knowledge[key].uniq
        end

        def print
          p :domain
          p :created_on
          p :expires_on
          p :updated_on
          p :registrar_name
          p :registrar_url
          p :registrant_contact
          p :admin_contact
          p :technical_contact

          p :server_name
          p :server_country
          p :server_location
          p :server_latitude
          p :server_longitude
          p :server_ip_owner

          p :emails
          p :title, title
          p :description, description
          p :twitter_author, twitter_author
          p :twitter_ids
          p :image, image
          p :responsive
          p :rss_feed
          p :atom_feed

          p :twitter_links
          p :linkedin_links
          p :instagram_links
          p :facebook_links
          p :googleplus_links
          p :github_links
          p :technologies
        end

        def p( key, val = nil )
          val = @knowledge[key] if val.nil?
          if val.is_a?( Array )
            printf TEMPLATE, key, val.join( ", ") if val.size > 0
          elsif val.is_a?( Whois::Record::Contact )
            printf TEMPLATE, key, ""
            [:name, :organization, :address, :city, :zip, :state, :country, :country_code, :phone, :fax, :email, :url, :created_on, :updated_on].each do |key|
              out = val.send( key )
              printf "%25s: %s\n", key, out if out && out != ""
            end
          else
            printf TEMPLATE, key, val if val
          end
        end

        def title
          @knowledge[:twitter_title] || @knowledge[:og_title] || @knowledge[:page_title]
        end

        def twitter_author
          @knowledge[:twitter_creator] || @knowledge[:twitter_by] || @knowledge[:twitter_site_author] || (@knowledge[:twitter_ids] || []).first
        end

        def description
          @knowledge[:twitter_description] || @knowledge[:og_description] || @knowledge[:description]
        end

        def image
          @knowledge[:twitter_image] || @knowledge[:og_image]
        end
      end

      class DNS
        def initialize
          @resolv = Dnsruby::Resolver.new
        end

        def find_domain( hostname )
          # puts "Looking for SOA of #{hostname}"
          soa = @resolv.query( hostname, "SOA" ).answer.select do |rr|
            rr.is_a? Dnsruby::RR::IN::SOA
          end

          return hostname if soa.length > 0

          parts = hostname.split( /\./ )
          return nil if parts.length <= 2

          find_domain( parts.slice(1,100).join( "." ) )
        end
      end
    end

    class NetClient
      # Look up the domain

      def get_knowledge( url )
        data = Socialinvestigator::Client::Net::PageKnowledge.new
        dns = Socialinvestigator::Client::Net::DNS.new

        uri = URI( url )

        data.remember( :hostname, uri.hostname )

        domain = dns.find_domain(uri.hostname)

        data.remember( :domain, domain )

        # Look at the domain info

        whois = Whois.lookup( domain )

        data.remember( :registered?, whois.registered? )
        if whois.registrar
          data.remember( :registrar_name, whois.registrar.name )
          data.remember( :registrar_url, whois.registrar.url )
        end

        data.remember( :created_on, whois.created_on.strftime( "%Y-%m-%d") ) if whois.created_on
        data.remember( :expires_on, whois.expires_on.strftime( "%Y-%m-%d") ) if whois.expires_on
        data.remember( :updated_on, whois.updated_on.strftime( "%Y-%m-%d") ) if whois.updated_on

        whois.contacts.each do |c|
          data.another( :emails, c.email.downcase ) if c.email
          case c.type
          when Whois::Record::Contact::TYPE_REGISTRANT
            data.remember( :registrant_contact, c )
          when Whois::Record::Contact::TYPE_ADMINISTRATIVE
            data.remember( :admin_contact, c )
          when Whois::Record::Contact::TYPE_TECHNICAL
            data.remember( :technical_contact, c )
          end
        end

        whois.parts.each do |p|
          if Whois::Record::Parser.parser_for(p).is_a? Whois::Record::Parser::Blank
            puts "Couldn't find a parser for #{p.host}:"
            data.another( :unparsed_whois, p.body )
          end
        end


        ip_address = Dnsruby::Resolv.getaddress uri.host

        if ip_address
          data.remember :ip_address, ip_address
          begin
            data.remember :server_name, Dnsruby::Resolv.getname( ip_address )
          rescue Dnsruby::NXDomain
            # Couldn't do the reverse lookup
          end

          location_info = HTTParty.get('http://freegeoip.net/json/' + ip_address)

          data.remember :server_country, location_info['country']
          data.remember :server_location, [location_info['city'], location_info['region_name']].select { |x| x }.join( ", ")
          data.remember :server_latitude, location_info['latitude']
          data.remember :server_longitude, location_info['longitude']

          ip_whois = Whois.lookup ip_address

          ip_whois.to_s.each_line.select { |x| x=~/Organization/ }.each do |org|
            if org =~ /Organization:\s*(.*)\n/
              data.another :server_ip_owner, $1
            end
          end
        end


        # Load up the response

        # client = HTTPClient.new
        # client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
        # response = client.get( url )
        #       # @ssl = p.peer_cert

        response = HTTParty.get url

        # require 'pp'
        # pp response.headers

        data.remember( :server, response.headers['server'] )


        # Parse the HTML

        parsed = Nokogiri.parse response.body

        data.remember( :page_title, parsed.title )

        # RSS Feed:
        if feed = parsed.css( 'link[type="application/rss+xml"]' ).first
          feed = feed.attributes['href'].value
          data.remember( :rss_feed, feed )
        end

        # Atom Feed:
        if feed = parsed.css( 'link[type="application/atom+xml"]' ).first
          feed = feed.attributes['href'].value
          data.remember( :atom_feed, feed )
        end



        # Meta tags

        meta = {}
        parsed.css( "meta[name]" ).each do |t|
          meta[t.attributes["name"].value] = t.attributes["content"].value if t.attributes["content"]
        end

        parsed.css( "meta[property]" ).each do |t|
          meta[t.attributes["property"].value] = t.attributes["content"].value
        end

        # require 'pp'
        # pp meta

        data.remember( :author, meta['author'] ) 
        data.remember( :description, meta['description'] ) 
        data.remember( :keywords, meta['keywords'] ) 
        data.remember( :generator, meta['generator'])

        data.remember( :responsive, true )  if meta["viewport"] =~ /width=device-width/


        # Check Twitter Card:

        data.remember( :twitter_title, meta["twitter:title"] ) 
        data.remember( :twitter_creator, meta["twitter:creator"] ) 
        if /@(.*)/.match( meta["twitter:creator"] )
          data.another( :twitter_ids, $1 )
        end
        data.remember( :twitter_site_author, meta["twitter:site"] )
        if /@(.*)/.match( meta["twitter:site"] )
          data.another( :twitter_ids, $1 )
        end
        data.remember( :twitter_image, meta["twitter:image"] ) 
        data.remember( :twitter_description, meta["twitter:description"] )

        # Open Graph

        data.remember( :og_title, meta["og:title"] ) 
        data.remember( :og_description, meta["og:description"] )
        data.remember( :og_type, meta["og:type"] ) 
        data.remember( :og_image, meta["og:image"] ) 


        # Look inside the body:


        # Twitter

        # Look for twitter links
        twitter_links = hrefs( matching_links( parsed, /twitter.com\/[^\/]*$/ ), true )
        data.remember( :twitter_links, twitter_links ) 

        twitter_ids = find_id_path( twitter_links, /twitter.com\/([^\/]*$)/  ).each do |id|
          data.another( :twitter_ids, id )
        end

        # Look for twitter shared links

        twitter_shared = matching_links( parsed, /twitter.com\/share/ )

        twitter_shared.each do |l|
          text = l['data-text']

          # See if there's a "by @user" in the text
          if /by\s*@([^\s]*)/.match text
            data.another( :twitter_ids, $1 )
            data.remember( :twitter_by, $1 ) 
          end

          # Look for all "@usernames" in the text
          if text
            text.split.select { |x| x =~ /@\s*/ }.each do |id|
              data.another( :twitter_ids, id.slice( 1,100 ) ) # We don't want the @
            end
          end

          # See if there's a via link on the anchor tag
          if l['data-via']
            data.another( :twitter_ids, l['data-via'])
          end


          possible_via = URI.decode( (URI(l['href']).query) || "" ).split( /&amp;/ ).collect { |x| x.split( /=/  ) }.select { |x| x[0] == 'via' }
          if possible_via.size > 0
            data.another( :twitter_ids, possible_via[0][1] )
          end
        end

        # Look for intent

        twitter_intent = hrefs( matching_links( parsed, /twitter.com\/intent/ ) )

        twitter_intent.each do |t|
          URI.decode( URI(t.gsub( / /, "+" )).query ).split( /&/ ).select do |x| 
            x =~ /via/
          end.collect do |x| 
            x.gsub( /via=/, "" )
          end.each do |via|
            data.another( :twitter_ids, via )
          end
        end
        # Look for email

        email_links = hrefs( matching_links( parsed, /mailto:/ ) )
        email_address = find_id_path( email_links, /mailto:(.*@.*\..*)/ ).each do |email|
          data.another( :emails, email )
        end

        # Linkedin

        linkedin_links = hrefs( matching_links( parsed, /linkedin.com/ ), true )
        data.remember( :linkedin_links, linkedin_links ) 

        # Instagram

        instagram_links = hrefs( matching_links( parsed, /instagram.com/ ) )
        data.remember( :instagram_links, instagram_links ) 

        # Facebook

        facebook_links = hrefs( matching_links( parsed, /facebook.com\/[^\/]*$/ ) )
        data.remember( :facebook_links, facebook_links ) 

        # Google plus

        googleplus_links = hrefs( matching_links( parsed, /plus.google.com\/[^\/]*$/ ) )
        data.remember( :googleplus_links, googleplus_links ) 

        # Github

        github_links = hrefs( matching_links( parsed, /github.com\/[^\/]*$/ ) )
        data.remember( :github_links, github_links ) 


        # Bonus!

        # Get this file from https://github.com/ElbertF/Wappalyzer/tree/master/share

        apps = Socialinvestigator::Config.config.apps_json
        if apps
          scripts = parsed.css( "script" ).collect { |x| x['src'] }.select { |x| x }
          # puts scripts

          apps['apps'].each do |app,checks|
            if checks['html']
              html_array = checks['html']
              html_array = [checks['html']] if html_array.is_a? String

              html_array.each do |html|
                result = check_regex( html, response.body )
                if result
                  data.another :technologies, app
                  data.another :technologies, checks['implies']
                end
              end
            end

            if checks['meta']
              checks['meta'].each do |k,code|
                result = check_regex( code, meta[k] )
                if result
                  data.another :technologies, app
                  data.another :technologies, checks['implies']
                end
              end
            end

            if checks['headers']
              checks['headers'].each do |k,code|
                result = check_regex( code, response.headers[k] )
                if result
                  data.another :technologies, app
                  data.another :technologies, checks['implies']
                end
              end
            end

            if checks['script']
              script_array = checks['script']
              script_array = [checks['script']] if script_array.is_a? String
              script_array.each do |script_regex|
                scripts.each do |script|
                  result = check_regex( script_regex, script)
                  if result
                    data.another :technologies, app
                    data.another :technologies, checks['implies']
                  end
                end
              end
            end
          end
        end
        data
      end

      def matching_links( parsed, regex )
        parsed.css( "a" ).collect do |x|
          if regex.match( x['href'] )
            x
          else
            nil
          end
        end.select do |x|
          x
        end
      end

      def hrefs( links, filter_shared = false )
        links.collect do |x|
          x['href']
        end.select do |url|
          if filter_shared
            !(url =~ /share/)
          else
            true
          end
        end.uniq
      end

      def find_id_path( links, regex )
        links.collect do |link|
          if regex.match( link )
            res = $1 || link
            if (res =~ /share/)
              nil
            else
              res
            end
          end
        end.select do |x|
          x
        end.uniq
      end

      def check_regex( mashed_regex, value )
        regex,result = mashed_regex.split( /\\;/ )
        md = Regexp.new( regex ).match( value )
        if md
          if result
            result = result.gsub( /\\1/, (md[1] || "" )).gsub( /\\2/, (md[2] || "") )
          else
            true
          end
        else
          false
        end
      end
    end
  end
end