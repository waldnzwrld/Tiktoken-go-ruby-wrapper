# fill this out with information for the tiktoken-wrapper gem
Gem::Specification.new do |spec|
    spec.name          = 'tiktoken-wrapper'
    spec.version       = '0.0.1'
    spec.authors       = ['Walden Bodtker']
    spec.email         = ['waldnzwrld@github.com', 'waldnzwrld@gmail.com']
    spec.summary       = 'A wrapper for the tiktoken go package'
    spec.description   = 'A wrapper for the tiktoken go package'
    spec.homepage      = "https://github.com/waldnzwrld/tiktoken-go-ruby-wrapper"
    spec.license       = 'MIT'

    # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
    # to allow pushing to a single host or delete this section to allow pushing to any host.
    if spec.respond_to?(:metadata)
        spec.metadata["allowed_push_host"] = "none" # don't allow this to be pushed anywhere

        spec.metadata["homepage_uri"] = spec.homepage
        spec.metadata["source_code_uri"] = "https://github.com/waldnzwrld/tiktoken-go-ruby-wrapper"
    else
        raise "RubyGems 2.0 or newer is required to protect against " \
        "public gem pushes."
    end

    # Specify which files should be added to the gem when it is released.
    # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
    spec.files         = Dir.chdir(File.expand_path(__dir__)) do
        `git ls-files -z`.split("\x0").reject do |f|
            f.match(%r{^(test|spec|features)/})
        end
    end
    spec.bindir        = "exe" # if your gem is a command line app
    spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
    spec.require_paths = ["lib", "ext"]

    spec.add_dependency "ffi"
    spec.add_dependency "benchmark"
    spec.add_dependency "memory_profiler"
    # be sure that go is installed and included in the path during a build
    spec.add_dependency "go"
end
