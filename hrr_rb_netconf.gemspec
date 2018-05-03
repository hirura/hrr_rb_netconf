
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

  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
