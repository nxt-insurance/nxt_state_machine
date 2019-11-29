require "bundler/setup"
require "pry"
require "nxt_state_machine"
require 'active_record'

ActiveRecord::Base.establish_connection adapter: "sqlite3", database: ":memory:"

require_relative 'support/schema'
require_relative 'support/models'

Dir['spec/support/**/*.rb'].each { |f| require "./#{f}" }

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
