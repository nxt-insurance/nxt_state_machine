module NxtStateMachine
  class StateMachine
    def initialize(context, **opts)
      @context = context
      @options = opts

      @states = Registry.new(
        :states,
        on_key_occupied: lambda do |name|
          raise NxtStateMachine::Errors::StateAlreadyRegistered,
                "An state with the name '#{name}' was already registered!"
        end
      )

      @transitions = TransitionsStore.new

      @events = Registry.new(
        :events,
        on_key_occupied: lambda do |name|
          raise NxtStateMachine::Errors::EventAlreadyRegistered,
                "An event with the name '#{name}' was already registered!"
        end
      )

      @initial_state = nil
    end

    attr_accessor :context, :states, :transitions, :initial_state, :events, :options

    def configure(&block)
      instance_exec(&block)
    end

    def get_state_with(method = nil, &block)
      method_or_block = (method || block)
      @get_state_with ||= method_or_block && Callable.new(method_or_block) || raise_missing_configuration_error(:get_state_with)
    end

    def set_state_with(method = nil, &block)
      method_or_block = (method || block)
      @set_state_with ||= method_or_block && Callable.new(method_or_block) || raise_missing_configuration_error(:set_state_with)
    end

    alias_method :transition_with, :set_state_with

    def set_state_with!(method = nil, &block)
      method_or_block = (method || block)
      @set_state_with_bang ||= method_or_block && Callable.new(method_or_block) || raise_missing_configuration_error(:set_state_with!)
    end

    alias_method :transition_with!, :set_state_with!

    def state(*names, **opts)
      defaults = { initial: false }
      opts.reverse_merge!(defaults)

      Array(names).map do |name|
        if opts.fetch(:initial) && initial_state.present?
          raise NxtStateMachine::Errors::InitialStateAlreadyDefined, ":#{initial_state.name} was already defined as the initial state"
        else
          state = State.new(name, opts)
          states[name] = state
          self.initial_state = state if opts.fetch(:initial)
          state
        end
      end
    end

    def transitions
      @transitions ||= events.values.flat_map(&:event_transitions)
    end

    def all_transitions_from_to(from: all_states, to: all_states)
      transitions.select { |transition| transition.transitions_from_to?(from, to) }
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
        transition = event.event_transitions.fetch(current_state_name)

        callbacks = event.callbacks_for_transition(transition)

        set_state_with_arity = state_machine.set_state_with.with_context(self).arity

        # In case of arity == 2 we handle callbacks, in case of arity == 3 we leave it to the caller
        # and do not wrap them in callables as this would be unexpected
        if set_state_with_arity == 2
          callbacks[:before].each do |callback|
            Callable.new(callback).with_context(self).call
          end

          result = false

          TransitionProxy.new(self, callbacks[:around]).call do
            result = transition.execute(self, state_machine.set_state_with, nil, *args, **opts)
          end

          callbacks[:after].each do |callback|
            Callable.new(callback).with_context(self).call
          end

          result
        elsif set_state_with_arity == 3
          transition.execute(self, state_machine.set_state_with, callbacks, *args, **opts)
        else
          raise ArgumentError, "state_machine.set_state_with can take 2 or 3 arguments"
        end
      end

      context.define_method "#{name}!" do |*args, **opts|
        state_machine.can_transition!(name, current_state_name)
        transition = event.event_transitions.fetch(current_state_name)

        callbacks = event.callbacks_for_transition(transition)
        set_state_with_arity = state_machine.set_state_with!.with_context(self).arity

        if set_state_with_arity == 2
          callbacks[:before].each do |callback|
            Callable.new(callback).with_context(self).call
          end

          result = nil

          TransitionProxy.new(self, callbacks[:around]).call do
            result = transition.execute(self, state_machine.set_state_with, nil, *args, **opts)
          end

          callbacks[:after].each do |callback|
            Callable.new(callback).with_context(self).call
          end

          result
        elsif set_state_with_arity == 3
          transition.execute(self, state_machine.set_state_with!, callbacks, *args, **opts)
        else
          raise ArgumentError, "state_machine.set_state_with! can take 2 or 3 arguments"
        end
      end

      context.define_method "can_#{name}?" do
        state_machine.can_transition?(name, current_state_name)
      end
    end

    def can_transition?(event, from)
      event = events[event]
      event && event.event_transitions.key?(from)
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
