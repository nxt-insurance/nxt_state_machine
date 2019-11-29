module NxtStateMachine
  class Event
    def initialize(name, state_machine:, &block)
      @state_machine = state_machine
      @name = name
      @transitions = Registry.new("#{name} event transitions")
      configure(&block)

      ensure_event_has_transitions
    end

    attr_reader :name, :state_machine, :transitions

    delegate :any_state, :all_states, :all_states_without, to: :state_machine

    def configure(&block)
      instance_exec(&block)
    end

    def transition(from:, to:, &block)
      Array(from).each do |from_state|
        transition = Transition.new(name, from: from_state, to: to, state_machine: state_machine, &block)
        # TODO: Would it not be better if this was a nested hash?
        state_machine.transitions << transition
        transitions[from_state] = transition
      end
    end

    def ensure_event_has_transitions
      return if transitions.size > 0

      raise NxtStateMachine::Errors::EventWithoutTransitions, "No transitions for event :#{name} defined"
    end
  end
end
