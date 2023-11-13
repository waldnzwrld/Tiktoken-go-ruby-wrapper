# frozen_string_literal: true
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "tiktoken/version"

Gem::Specification.new do |spec|
  spec.name          = "tiktoken-encoder"
  spec.version       = Tiktoken::VERSION
  spec.authors       = ["Walden Bodtker"]
  spec.email         = ["waldnzwrld@github.com", "waldnzwrld@gmail.com"]
  spec.summary       = "A wrapper for the tiktoken go package"
  spec.description   = "A wrapper for the tiktoken go package, exposing it's core functionality to Ruby via cgo."
  spec.homepage      = "https://github.com/github/tiktoken-go-wrapper-gem"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "https://rubygems.pkg.github.com/github"
    spec.metadata["homepage_uri"] = spec.homepage
    spec.metadata["source_code_uri"] = "https://github.com/github/tiktoken-go-wrapper-gem"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
    "public gem pushes."
  end

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  # do not include go files scripts or gem files
  # do not include go.mod or go.sum files
  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(script|spec|test|exe|)/})
  end
  spec.bindir        = "exe" # if your gem is a command line app
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = %w[lib]
  spec.extensions = %w[ext/extconf.rb]


  spec.add_development_dependency "benchmark", "~> 0.2"
  spec.add_development_dependency "bundler", "~> 2.2.33"
  spec.add_development_dependency "memory_profiler", "~> 1.0"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "mocha", "~> 2.0"
  spec.add_development_dependency "pry", "~> 0.14.1"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rubocop-github", "~> 0.20.0"
end
