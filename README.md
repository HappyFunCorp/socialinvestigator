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

Search hacker news for a url:

    $ socialinvestigator hn search http://willschenk.com

Setting up twitter.  You'll need to register a twitter app for this to work.
Full walk through is here http://willschenk.com/scripting-twitter.

Once you have the twitter info, you put it in using the twitter config command:

    $ socialinvestigator twitter config
    
## Contributing

1. Fork it ( https://github.com/sublimeguile/socialinvestigator/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
