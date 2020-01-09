module NxtStateMachine
  class Event
    include NxtRegistry

    def initialize(name, state_machine:, &block)
      @state_machine = state_machine
      @name = name
      @event_transitions = registry("#{name} event transitions")
      @names = Event::Names.build(name)

      configure(&block)

      ensure_event_has_transitions
    end

    attr_reader :name, :state_machine, :event_transitions, :names

    delegate :before_transition,
             :after_transition,
             :around_transition,
             :on_error,
             :on_error!,
             :any_state,
             :all_states,
             :all_states_except,
             to: :state_machine

    def transitions(from:, to:, &block)
      Array(from).each do |from_state|
        transition = Transition::Factory.new(name, from: from_state, to: to, state_machine: state_machine, &block)
        state_machine.transitions << transition
        event_transitions.register(from_state, transition)
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
