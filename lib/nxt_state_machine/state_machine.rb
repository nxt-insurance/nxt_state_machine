module NxtStateMachine
  class StateMachine
    def initialize(name, class_context, event_registry, **opts)
      @name = name
      @class_context = class_context
      @options = opts

      @states = NxtStateMachine::StateRegistry.new
      @transitions = []
      @events = event_registry
      @callbacks = CallbackRegistry.new
      @error_callback_registry = ErrorCallbackRegistry.new
      @defuse_registry = DefuseRegistry.new

      @initial_state = nil
    end

    attr_reader :class_context, :events, :options, :callbacks, :name, :error_callback_registry, :defuse_registry
    attr_accessor :initial_state

    def get_state_with(method = nil, &block)
      @get_state_with ||= (method || block) || raise_missing_configuration_error(:get_state_with)
    end

    def set_state_with(method = nil, &block)
      @set_state_with ||= (method || block) || raise_missing_configuration_error(:set_state_with)
    end

    def set_state_with!(method = nil, &block)
      @set_state_with_bang ||= (method || block) || raise_missing_configuration_error(:set_state_with!)
    end

    def state(*names, **opts, &block)
      defaults = { initial: false }
      opts.reverse_merge!(defaults)
      machine = self

      Array(names).map do |name|
        if opts.fetch(:initial) && initial_state.present?
          raise NxtStateMachine::Errors::InitialStateAlreadyDefined, ":#{initial_state.enum} was already defined as the initial state"
        else
          state = new_state_class(&block).new(name, self, **opts.reverse_merge(index: states.size))
          states.register(name, state)
          self.initial_state = state if opts.fetch(:initial)

          class_context.define_method "#{name}?" do
            machine.current_state_name(self) == name
          end

          state
        end
      end
    end

    def states(*names, **opts, &block)
      # method overloading in ruby ;-)
      return @states unless names.any?

      state(*names, **opts, &block)
    end

    def transitions
      @transitions ||= events.values.flat_map(&:event_transitions)
    end

    def all_transitions_from_to(from: all_states, to: all_states)
      transitions.select { |transition| transition.transitions_from_to?(from, to) }
    end

    def events_for_state(state)
      events.values.select { |event| event.transitions_from?(state) }
    end

    def any_state
      states.values.map(&:enum)
    end

    def event_methods
      event_names = events.keys
      event_names_with_bang = event_names.map { |e| e + '!' }

      (event_names + event_names_with_bang).map(&:to_sym)
    end

    alias_method :all_states, :any_state

    def all_states_except(*excluded)
      all_states - excluded
    end

    def event(name, **options, &block)
      name = name.to_sym
      event = Event.new(name, self, **options, &block)
      events.register(name, event)

      Event::Names.set_state_method_map(name).each do |event_name, set_state_method|
        class_context.define_method event_name do |*args, **opts|
          event.state_machine.can_transition!(name, event.state_machine.current_state_name(self))
          transition = event.event_transitions.resolve!(event.state_machine.current_state_name(self))
          # Transition is build every time and thus should be thread safe!
          transition.build_transition(event, self, set_state_method, *args, **opts)
        end
      end

      class_context.define_method "can_#{name}?" do
        event.state_machine.can_transition?(name, event.state_machine.current_state_name(self))
      end
    end

    def can_transition?(event_name, from)
      event = events.resolve!(event_name)
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

    def on_success(from:, to:, run: nil, &block)
      callbacks.register(from, to, :success, run, block)
    end

    def defuse(errors = [], from:, to:)
      defuse_registry.register(from, to, errors)
    end

    def on_error(error = StandardError, from:, to:, run: nil, &block)
      error_callback_registry.register(from, to, error, run, block)
    end

    def on_error!(error = StandardError, from:, to:, run: nil, &block)
      error_callback_registry.register!(from, to, error, run, block)
    end

    def around_transition(from:, to:, run: nil, &block)
      callbacks.register(from, to, :around, run, block)
    end

    def configure(&block)
      instance_exec(&block)
      self
    end

    # TODO: Everything that require context should live in some sort of proxy
    def run_before_callbacks(transition, context)
      run_callbacks(transition, :before, context)
    end

    def run_after_callbacks(transition, context)
      run_callbacks(transition, :after, context)
    end

    def run_success_callbacks(transition, context)
      run_callbacks(transition, :success, context)
    end

    def find_error_callback(error, transition)
      error_callback_registry.resolve(error, transition)
    end

    def run_callbacks(transition, kind, context)
      current_callbacks = callbacks.resolve!(transition, kind)
      return unless current_callbacks.any?

      current_callbacks.each do |callback|
        Callable.new(callback).bind(context).call(transition)
      end

      true
    end

    def current_state_name(context)
      Callable.new(get_state_with).bind(context).call(target(context))
    end

    def target(context)
      @target_method ||= (options[:target] || :itself)
      context.send(@target_method)
    end

    private

    def raise_missing_configuration_error(method)
      raise NxtStateMachine::Errors::MissingConfiguration, "Configuration method :#{method} was not defined"
    end

    def new_state_class(&block)
      if block
        Class.new(NxtStateMachine::State, &block)
      else
        NxtStateMachine::State
      end
    end
  end
end
