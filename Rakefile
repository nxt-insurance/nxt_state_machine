require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

task default: :spec

namespace :graph do
  desc 'draw the graph of a state machine'
  task :draw, [:state_machine_class] do |t, args|
    state_machine_class = Object.const_get(args.fetch(:state_machine_class))
    state_machine = state_machine_class.state_machine
    NxtStateMachine::Graph.new(state_machine).draw
  end
end
