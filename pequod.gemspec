# coding: utf-8
# frozen_string_literal: true
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'pequod/version'

Gem::Specification.new do |spec|
  spec.name          = "pequod"
  spec.version       = Pequod::VERSION
  spec.authors       = ["barrerajl"]
  spec.email         = ["jlbarrera@aspgems.com"]

  spec.summary       = %q{A gem to manage docker and docker-compose for ruby projects.}
  spec.description   = %q{A gem to manage docker and docker-compose for ruby projects. Use it with caution.}
  spec.homepage      = "https://github.com/aspgems/pequod"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.14"
  spec.add_development_dependency "rake", "~> 10.0"

  spec.add_dependency 'thor'
  spec.add_dependency 'docker-api'
end
