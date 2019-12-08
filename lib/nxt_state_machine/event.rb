module NxtStateMachine
  class Event
    def initialize(name, state_machine:, &block)
      @state_machine = state_machine
      @name = name
      @event_transitions = Registry.new("#{name} event transitions")
      @callbacks = ActiveSupport::HashWithIndifferentAccess.new
      configure(&block)

      ensure_event_has_transitions
    end

    attr_reader :name, :state_machine, :event_transitions, :callbacks

    delegate :any_state, :all_states, :all_states_without, to: :state_machine

    def configure(&block)
      instance_exec(&block)
    end

    def transitions(from:, to:, &block)
      Array(from).each do |from_state|
        transition = Transition.new(name, from: from_state, to: to, state_machine: state_machine, &block)
        state_machine.transitions << transition
        event_transitions[from_state] = transition
      end
    end

    alias_method :transition, :transitions

    def before_transition(from:, to:, run: nil, &block)
      add_callbacks(from, to, :before, run, block)
    end

    def after_transition(from:, to:, run: nil, &block)
      add_callbacks(from, to, :after, run, block)
    end

    def around_transition(from:, to:, run: nil, &block)
      add_callbacks(from, to, :around, run, block)
    end

    def add_callbacks(from, to, kind, method, block)
      method_or_block = method || block

      Array(from).each do |from_state|
        callbacks[from_state] ||= ActiveSupport::HashWithIndifferentAccess.new
        callbacks[from_state][to] ||= ActiveSupport::HashWithIndifferentAccess.new
        callbacks[from_state][to][kind] ||= []

        if method_or_block
          callbacks[from_state][to][kind] << method_or_block
        end
      end
    end

    def callbacks_for_transition(transition, kind = nil)
      @callbacks_for_transition ||= ActiveSupport::HashWithIndifferentAccess.new

      all_callbacks = @callbacks_for_transition[transition.id] ||= begin
        empty_callbacks = { before: [], after: [], around: [] }.with_indifferent_access
        # TODO: This is bullshit
        callbacks[transition.from] ||= ActiveSupport::HashWithIndifferentAccess.new
        callbacks[transition.from][transition.to] ||= ActiveSupport::HashWithIndifferentAccess.new
        all_callbacks = callbacks.fetch(transition.from).fetch(transition.to)
        empty_callbacks.deep_merge(all_callbacks)
      end

      return all_callbacks unless kind

      all_callbacks.fetch(kind)
    end

    def ensure_event_has_transitions
      return if event_transitions.size > 0

      raise NxtStateMachine::Errors::EventWithoutTransitions, "No transitions for event :#{name} defined"
    end
  end
end
