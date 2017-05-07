# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'apns_gatling/version'

Gem::Specification.new do |spec|
  spec.name          = "apns_gatling"
  spec.version       = ApnsGatling::VERSION
  spec.licenses      = ["MIT"]
  spec.authors       = ["Cloud"]
  spec.email         = ["cloudcry@gmail.com"]

  spec.summary       = %q{A Ruby Token Based Authentication APNs HTTP/2 gem.}
  spec.description   = %q{ApnsGatling is a token based authenitcation APNs HTTP/2 gem. }
  spec.homepage      = "https://github.com/cloudorz/apns_gatling"

  spec.required_ruby_version = '~> 2.0'

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "http-2", "~> 0.8.3"
  spec.add_dependency "jwt", "~> 1.5"
  spec.add_dependency "json", "~> 2.0"

  spec.add_development_dependency "bundler", "~> 1.13"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "minitest", "~> 5.0"
end
