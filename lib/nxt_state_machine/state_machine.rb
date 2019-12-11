module NxtStateMachine
  class StateMachine
    def initialize(context, **opts)
      @context = context
      @options = opts

      @states = Registry.new(
        :states,
        on_key_occupied: Proc.new do |name|
          raise NxtStateMachine::Errors::StateAlreadyRegistered,
                "An state with the name '#{name}' was already registered!"
        end
      )

      @transitions = TransitionsStore.new

      @events = Registry.new(
        :events,
        on_key_occupied: Proc.new do |name|
          raise NxtStateMachine::Errors::EventAlreadyRegistered,
                "An event with the name '#{name}' was already registered!"
        end
      )

      @callbacks = CallbackRegistry.new

      @initial_state = nil
    end

    attr_reader :context, :states, :transitions, :events, :options, :callbacks
    attr_accessor :initial_state

    def get_state_with(method = nil, &block)
      method_or_block = (method || block)
      @get_state_with ||= method_or_block && Callable.new(method_or_block) || raise_missing_configuration_error(:get_state_with)
    end

    def set_state_with(method = nil, &block)
      method_or_block = (method || block)
      @set_state_with ||= method_or_block && Callable.new(method_or_block) || raise_missing_configuration_error(:set_state_with)
    end

    def set_state_with!(method = nil, &block)
      method_or_block = (method || block)
      @set_state_with_bang ||= method_or_block && Callable.new(method_or_block) || raise_missing_configuration_error(:set_state_with!)
    end

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

    # TODO: This is not even used so far?!
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
      # TODO: This is the context of the state machine, which is not the instance but the class itself!
      context.define_method name do |*args, **opts|
        state_machine.can_transition!(name, current_state_name)
        transition = event.event_transitions.fetch(current_state_name)
        transition.execute_with(self, :set_state_with, *args, **opts)
      end

      context.define_method "#{name}!" do |*args, **opts|
        state_machine.can_transition!(name, current_state_name)
        transition = event.event_transitions.fetch(current_state_name)
        transition.execute_with(self, :set_state_with!, *args, **opts)
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

    def before_transition(from:, to:, run: nil, &block)
      callbacks.register(from, to, :before, run, block)
    end

    def after_transition(from:, to:, run: nil, &block)
      callbacks.register(from, to, :after, run, block)
    end

    def around_transition(from:, to:, run: nil, &block)
      callbacks.register(from, to, :around, run, block)
    end

    def configure(&block)
      instance_exec(&block)
    end

    def run_before_callbacks(transition, context)
      run_callbacks(transition, :before, context)
    end

    def run_after_callbacks(transition, context)
      run_callbacks(transition, :after, context)
    end

    def run_callbacks(transition, kind, context)
      current_callbacks = callbacks.resolve(transition)[kind]

      current_callbacks.each do |callback|
        Callable.new(callback).with_context(context).call
      end
    end

    def execute_transition(transition, context, &block)
      TransitionProxy.new(context, callbacks.resolve(transition)[:around]).call(&block)
    end

    private

    def raise_missing_configuration_error(method)
      raise NxtStateMachine::Errors::MissingConfiguration, "Configuration method :#{method} was not defined"
    end
  end
end
