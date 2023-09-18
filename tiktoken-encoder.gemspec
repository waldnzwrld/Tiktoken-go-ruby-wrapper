# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = 'tiktoken-encoder'
  spec.version       = '0.0.1'
  spec.authors       = ['Walden Bodtker']
  spec.email         = ['waldnzwrld@github.com', 'waldnzwrld@gmail.com']
  spec.summary       = 'A wrapper for the tiktoken go package'
  spec.description   = 'A wrapper for the tiktoken go package, which exposes the core functionality of the tiktoken package to Ruby through cgo.'
  spec.homepage      = 'https://github.com/waldnzwrld/tiktoken-go-ruby-wrapper'
  spec.license       = 'MIT'

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = 'none' # don't allow this to be pushed anywhere
    spec.metadata['homepage_uri'] = spec.homepage
    spec.metadata['source_code_uri'] = 'https://github.com/waldnzwrld/tiktoken-go-ruby-wrapper'
  else
    raise 'RubyGems 2.0 or newer is required to protect against ' \
    'public gem pushes.'
  end

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  # do not include go files scripts or gem files
  # do not include go.mod or go.sum files
  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(go|script|spec|test|exe|lib|ext)/}) ||
      f.match(/^(go.mod|go.sum|tiktoken-wrapper.go)/)
  end
  spec.bindir        = 'exe' # if your gem is a command line app
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = %w[lib ext]

  spec.add_dependency 'benchmark', '~> 0.2'
  spec.add_dependency 'ffi', '~> 1.15'
  spec.add_dependency 'memory_profiler', '~> 1.0'

  spec.add_development_dependency 'minitest', '~> 5.0'
  spec.add_development_dependency 'mocha', '~> 2.0'
  spec.add_development_dependency 'pry', '~> 0.14.1'
  spec.add_development_dependency 'rubocop-github', '~> 0.20.0'
end
