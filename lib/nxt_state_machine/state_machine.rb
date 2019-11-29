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
      @get_state_with ||= block || raise_missing_configuration_error(:get_state_with)
    end

    def set_state_with(&block)
      @set_state_with ||= block || raise_missing_configuration_error(:set_state_with)
    end

    def set_state_with!(&block)
      @set_state_with_bang ||= block || raise_missing_configuration_error(:set_state_with!)
    end

    def state(name, initial: false)
      if initial && initial_state.present?
        raise NxtStateMachine::Errors::InitialStateAlreadySet, ":#{initial_state.name} was already set as the initial state"
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
      event = Event.new(name, state_machine: self, &block)
      events[name] = event

      # we might also put this in a module for easy overwriting
      context.define_method name do |*args, **opts|
        state_machine.can_transition!(name, current_state_name)
        transition = state_machine.events[name].transitions.fetch(current_state_name)

        transition.execute(self, state_machine.set_state_with, *args, **opts)
      end

      context.define_method "#{name}!" do |*args, **opts|
        state_machine.can_transition!(name, current_state_name)
        transition = state_machine.events[name].transitions.fetch(current_state_name)

        transition.execute(self, state_machine.set_state_with!, *args, **opts)
      end

      context.define_method "can_#{name}?" do
        state_machine.can_transition?(name, current_state_name)
      end
    end

    def can_transition?(event, from)
      event = events[event]
      event && event.transitions.key?(from)
    end

    def can_transition!(event, from)
      return true if can_transition?(event, from)
      raise NxtStateMachine::Errors::TransitionNotDefined, "No transition :#{event} for state :#{from} defined"
    end

    def raise_missing_configuration_error(method)
      raise NxtStateMachine::Errors::MissingConfiguration, "Configuration method :#{method} was not defined"
    end
  end
end
