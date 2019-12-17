module NxtStateMachine
  class StateMachine
    def initialize(name, class_context, event_registry, **opts)
      @name = name
      @class_context = class_context
      @options = opts

      @states = Registry.new(
        :states,
        on_key_occupied: Proc.new do |key|
          raise NxtStateMachine::Errors::StateAlreadyRegistered,
                "A state with the name '#{key}' was already registered!"
        end
      )

      @transitions = TransitionsStore.new

      @events = event_registry

      @callbacks = CallbackRegistry.new

      @initial_state = nil
    end

    attr_reader :class_context, :states, :transitions, :events, :options, :callbacks, :name
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
      # TODO: Add is_in_state? methods
      defaults = { initial: false }
      opts.reverse_merge!(defaults)

      Array(names).map do |name|
        if opts.fetch(:initial) && initial_state.present?
          raise NxtStateMachine::Errors::InitialStateAlreadyDefined, ":#{initial_state.name} was already defined as the initial state"
        else
          state = State.new(name, opts)
          states[name] = state
          self.initial_state = state if opts.fetch(:initial)

          class_context.define_method "#{name}?" do
            # States internally are always strings
            state_machine.current_state_name(self) == name.to_s
          end

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

    def all_states_except(*excluded)
      all_states - excluded
    end

    def event(name, &block)
      event = Event.new(name, state_machine: self, &block)
      events[name] = event

      class_context.define_method name do |*args, **opts|
        event.state_machine.can_transition!(name, event.state_machine.current_state_name(self))
        transition = event.event_transitions.fetch(event.state_machine.current_state_name(self))
        transition.execute_with(name, self, :set_state_with, *args, **opts)
      end

      class_context.define_method "#{name}!" do |*args, **opts|
        event.state_machine.can_transition!(name, event.state_machine.current_state_name(self))
        transition = event.event_transitions.fetch(event.state_machine.current_state_name(self))
        transition.execute_with("#{name}!", self, :set_state_with!, *args, **opts)
      end

      class_context.define_method "can_#{name}?" do
        event.state_machine.can_transition?(name, event.state_machine.current_state_name(self))
      end
    end

    def can_transition?(event_name, from)
      normalized_event_name = event_name.to_s.gsub('!', '')
      event = events[normalized_event_name]
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
      self
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
        Callable.new(callback).with_context(context).call(transition)
      end
    end

    def current_state_name(context)
      get_state_with.with_context(context).call
    end

    private

    def raise_missing_configuration_error(method)
      raise NxtStateMachine::Errors::MissingConfiguration, "Configuration method :#{method} was not defined"
    end
  end
end
