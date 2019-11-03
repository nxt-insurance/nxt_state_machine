module NxtStateMachine
  class StateMachine
    def initialize(context)
      @context = context

      @states = Registry.new(
        :states,
        on_key_error: lambda do |name|
          raise NxtStateMachine::Errors::StateAlreadyRegistered,
                "An state with the name '#{name}' was already registered!"
        end
      )

      @transitions = TransitionsStore.new

      @events = Registry.new(
        :events,
        on_key_error: lambda do |name|
          raise NxtStateMachine::Errors::EventAlreadyRegistered,
                "An event with the name '#{name}' was already registered!"
        end
      )

      @initial_state = nil
    end

    attr_accessor :context, :states, :transitions, :initial_state, :events

    def configure(&block)
      instance_exec(&block)
    end

    def get_state_with(&block)
      @get_state ||= block
    end

    def set_state_with(&block)
      @set_state_with ||= block
    end

    def state(name, initial: false)
      if initial && initial_state.present?
        raise InitialStateAlreadySet, ":#{initial_state.name} was already set as the initial state"
      else
        state = State.new(name, initial: initial)
        states[name] = state
        self.initial_state = state if initial
        state
      end
    end

    def any_state
      states.values.map(&:name)
    end

    alias_method :all_states, :any_state

    def all_states_without(*excluded)
      all_states - excluded
    end

    def event(name, &block)
      # should probably add_transition
      event = Event.new(name, state_machine: self, &block)
      events[name] = event

      # TODO: May transition method
      # TODO: Bang event method
      # we might also put this in a module for easy overwriting
      context.define_method name do |*args, **opts|
        # would we raise an error in case transition is not valid?
        transition = state_machine.events[name].transitions.fetch(current_state_name)
        transition.execute(self, *args, **opts)
      end

      context.define_method "can_#{name}?" do
        state_machine.can_transition?(name)
      end
    end

    def can_transition?(event)
      events[event].transitions.key?(current_state_name)
    end
  end
end
