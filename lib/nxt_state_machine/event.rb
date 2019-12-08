module NxtStateMachine
  class Event
    def initialize(name, state_machine:, &block)
      @state_machine = state_machine
      @name = name
      @event_transitions = Registry.new("#{name} event transitions")

      configure(&block)

      ensure_event_has_transitions
    end

    attr_reader :name, :state_machine, :event_transitions

    delegate :before_transition,
             :after_transition,
             :around_transition,
             :any_state,
             :all_states,
             :all_states_without,
             to: :state_machine

    def transitions(from:, to:, &block)
      Array(from).each do |from_state|
        transition = Transition.new(name, from: from_state, to: to, state_machine: state_machine, &block)
        state_machine.transitions << transition
        event_transitions[from_state] = transition
      end
    end

    alias_method :transition, :transitions

    private

    def configure(&block)
      instance_exec(&block)
    end

    def ensure_event_has_transitions
      return if event_transitions.size > 0

      raise NxtStateMachine::Errors::EventWithoutTransitions, "No transitions for event :#{name} defined"
    end
  end
end
