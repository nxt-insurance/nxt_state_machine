module NxtStateMachine
  class StateMachine
    def initialize(context, **opts)
      @context = context
      @options = opts

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

    attr_accessor :context, :states, :transitions, :initial_state, :events, :options

    def configure(&block)
      instance_exec(&block)
    end

    def get_state_with(method = nil, &block)
      @get_state_with ||= (method || block) || raise_missing_configuration_error(:get_state_with)
    end

    def set_state_with(method = nil, &block)
      @set_state_with ||= (method || block) || raise_missing_configuration_error(:set_state_with)
    end

    alias_method :transition_with, :set_state_with

    def set_state_with!(method = nil, &block)
      @set_state_with_bang ||= (method || block) || raise_missing_configuration_error(:set_state_with!)
    end

    alias_method :transition_with!, :set_state_with!

    def state(*names, **opts)
      defaults = { initial: false }
      opts.reverse_merge!(defaults)

      Array(names).map do |name|
        if opts.fetch(:initial) && initial_state.present?
          raise NxtStateMachine::Errors::InitialStateAlreadySet, ":#{initial_state.name} was already set as the initial state"
        else
          state = State.new(name, opts)
          states[name] = state
          self.initial_state = state if opts.fetch(:initial)
          state
        end
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
        transition = event.event_transitions.fetch(current_state_name)

        empty_callbacks = { before: [], after: [] }
        callbacks = event.callbacks[transition.from] ||= empty_callbacks
        callbacks = empty_callbacks.deep_merge(callbacks)

        set_state_with_arity = CallCenter.new(state_machine.set_state_with).with_context(self).arity

        if set_state_with_arity == 3
          callbacks[:before].each do |callback|
            callback.run(self)
          end

          # TODO: Does this even work with an arity of 3? --> test please!!!
          # TODO: Proxy and around callback
          result = false

          proxy = Proc.new do
            result = transition.execute(self, state_machine.set_state_with, nil, *args, **opts)
          end

          proxy.call

          callbacks[:after].each do |callback|
            callback.run(self)
          end

          result
        elsif set_state_with_arity == 4
          transition.execute(self, state_machine.set_state_with, callbacks, *args, **opts)
        else
          raise StandardError, 'set_state_with must at least have an arity of 3' # TODO: Make this a proper error
        end
      end

      context.define_method "#{name}!" do |*args, **opts|
        state_machine.can_transition!(name, current_state_name)
        transition = event.event_transitions.fetch(current_state_name)

        empty_callbacks = { before: [], after: [] }
        callbacks = event.callbacks[transition.from] ||= empty_callbacks
        callbacks = empty_callbacks.deep_merge(callbacks)

        # TODO: Probably should rather be callable object instead of call center
        set_state_with_arity = CallCenter.new(state_machine.set_state_with!).with_context(self).arity

        if set_state_with_arity == 3
          callbacks[:before].each do |callback|
            callback.run(self)
          end

          result = nil

          proxy = Proc.new do
            result = transition.execute(self, state_machine.set_state_with, nil, *args, **opts)
          end

          proxy.call

          callbacks[:after].each do |callback|
            callback.run(self)
          end

          result
        elsif set_state_with_arity == 4
          transition.execute(self, state_machine.set_state_with!, callbacks, *args, **opts)
        else
          raise StandardError, 'Block must at least have an arity of 3' # TODO: Make this a proper error
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
