module NxtStateMachine
  class Event
    def initialize(state_machine, name)
      @state_machine = state_machine
      @name = name
      @transitions = {}
    end

    attr_reader :name, :state_machine, :transitions

    def configure(&block)
      instance_exec(&block)
    end

    def transition(from:, to:, &block)
      Array(from).each do |from|
        transition = Transition.new(name, from: from, to: to, &block)
        state_machine.transitions[from] = transition
        transitions[from] = transition
      end
    end
  end
end
