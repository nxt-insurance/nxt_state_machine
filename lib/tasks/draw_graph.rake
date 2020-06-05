namespace :graph do
  desc 'draw the graph of a state machine'
  task :draw, [:state_machine_class] => [:environment] do |_, args|
    state_machine_class = Object.const_get(args.fetch(:state_machine_class))
    state_machine = state_machine_class.state_machine
    NxtStateMachine::Graph.new(state_machine).draw
  end
end
