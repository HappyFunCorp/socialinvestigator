# Socialinvestigator

This is a took to help track down who is linking to your site.

## Installation

Currently this tool is available command line only, and is installed by:

    $ gem install socialinvestigator

Then you can run the command 'socialinvestigator' to begin using it.

    $ socialinvestigator

## Usage

Full help
    $ socialinvestigator help

## Hacker News Search

Code walk through: http://willschenk.com/making-a-command-line-utility-with-gems-and-thor

Search hacker news for a url:

    $ socialinvestigator hn search http://willschenk.com

## Looking up information from a URL

Code walk through: http://willschenk.com/personal-information-from-only-a-url

Start with a URL, figure out what you can find:

    $ socialinvestigator net page_info http://willschenk.com

To analyse the technology stack, you need to load the datafile from
https://github.com/ElbertF/Wappalyzer
which can be done with this command:

    $ socialinvestigator net get_apps_json

## Twitter Scripting

_This will be documented soon_

Code walk through: http://willschenk.com/scripting-twitter

You'll need to register a twitter app for this to work.  Once you have the twitter info, you put it in using the twitter config command:

    $ socialinvestigator twitter config
    
## Contributing

1. Fork it ( https://github.com/sublimeguile/socialinvestigator/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
