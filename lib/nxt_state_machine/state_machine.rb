module NxtStateMachine
  class StateMachine
    def initialize(context)
      @context = context
      @states = {}
      @transitions = {}
      @events = {}
      @current_state = nil
    end

    attr_accessor :context, :states, :transitions, :current_state, :events

    def configure(&block)
      instance_exec(&block)
    end

    def state(name, initial: false)
      # should probably add_state
      state = State.new(name, initial: initial)
      states[name] = state
      self.current_state = state if initial
      state
    end

    def any_state
      states.map(&:name)
    end

    alias_method :all_states, :any_state

    def all_states_without(*excluded)
      all_states - excluded
    end

    def event(name, &block)
      # should probably add_transition
      event = Event.new(self, name)
      event.configure(&block)
      events[name] = event

      # TODO: May transition method
      # TODO: Bang event method
      # we might also put this in a module for easy overwriting
      context.define_method name do |*args, **opts|
        # we might want to pass in the current_state here
        transition = state_machine.events[name].transitions[current_state.name]
        transition.execute(self, *args, **opts)
      end
    end

    def can_transition_to?(state)

    end
  end
end
