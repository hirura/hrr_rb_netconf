# coding: utf-8
# vim: et ts=2 sw=2

lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "hrr_rb_netconf/version"

Gem::Specification.new do |spec|
  spec.name          = "hrr_rb_netconf"
  spec.version       = HrrRbNetconf::VERSION
  spec.license       = 'Apache-2.0'
  spec.summary       = %q{Pure Ruby NETCONF server implementation}
  spec.description   = %q{Pure Ruby NETCONF server implementation}
  spec.authors       = ["hirura"]
  spec.email         = ["hirura@gmail.com"]
  spec.homepage      = "https://github.com/hirura/hrr_rb_netconf"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.require_paths = ["lib"]

  spec.required_ruby_version = '>= 2.0.0'

  spec.add_dependency "hrr_rb_relaxed_xml"

  spec.add_development_dependency "rake", ">= 12.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "simplecov", "~> 0.16"
end
