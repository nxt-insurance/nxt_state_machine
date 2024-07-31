lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "nxt_state_machine/version"

Gem::Specification.new do |spec|
  spec.name          = "nxt_state_machine"
  spec.version       = NxtStateMachine::VERSION
  spec.authors       = ["Andreas Robecke", "Nils Sommer", "Raphael Kallensee", "Lütfi Demirci"]
  spec.email         = ["a.robecke@getsafe.de"]

  spec.summary       = %q{A rich but straight forward state machine library}
  spec.description   = %q{A state machine library that can be used with ActiveRecord or in plain ruby and should be easy to customize for other integrations}
  spec.homepage      = "https://github.com/nxt-insurance/nxt_state_machine"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = 'https://rubygems.org'

    spec.metadata["homepage_uri"] = spec.homepage
    spec.metadata["source_code_uri"] = "https://github.com/nxt-insurance/nxt_state_machine"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "activesupport"
  spec.add_dependency "nxt_registry", "~> 0.3.0"

  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 13.2"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "activerecord"
  spec.add_development_dependency "sqlite3", "~> 1.4.4"
  spec.add_development_dependency "ruby-graphviz"
end
