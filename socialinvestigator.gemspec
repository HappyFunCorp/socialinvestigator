# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'socialinvestigator/version'

Gem::Specification.new do |spec|
  spec.name          = "socialinvestigator"
  spec.version       = Socialinvestigator::VERSION
  spec.authors       = ["Will Schenk"]
  spec.email         = ["wschenk@gmail.com"]
  spec.summary       = %q{Simple command line tool to look at urls.}
  spec.description   = %q{Simple command line tool to look at urls.}
  spec.homepage      = "https://github.com/sublimeguile/socialinvestigator"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency 'thor'
  spec.add_dependency 'httparty'
  spec.add_dependency 'twitter'

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"
end
