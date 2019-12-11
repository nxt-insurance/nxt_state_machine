module NxtStateMachine
  class Transition
    def initialize(name, from:, to:, state_machine:, &block)
      @name = name
      @from = from
      @to = to
      @state_machine = state_machine
      @block = block
      @context = nil

      # TODO: Write a spec that verifies that transitions are unique
      ensure_states_exist
    end

    attr_reader :name, :from, :to

    # TODO: Probably would make sense if we could also define the event name to be passed in
    # => This way we could differentiate what event triggered the callback!!!

    # TODO: Prepare?
    # What if we would return a new object here: executable_transition - or transitions would be transition templates or so
    def execute_with(context, set_state_with_method, callbacks = nil, *args, **opts)
      # TODO: We should probably rename this to trigger_callbacks or something
      # This exposes the transition block on the transition itself so it can be executed through transition.apply_block later in :set_state_with
      self.block_proxy = Proc.new do
        if block
          context.instance_exec(*args, **opts, &block)
        end
      end

      self.context = context

      state_machine.send(set_state_with_method).with_context(context).call(self, context, callbacks)
    end

    def apply_block
      block_proxy.call
    end

    def execute(&block)
      TransitionProxy.new(context, state_machine.callbacks.resolve(self)[:around]).call(&block)
    end

    def run_before_callbacks
      state_machine.run_before_callbacks(self, context)
    end

    def run_after_callbacks
      state_machine.run_after_callbacks(self, context)
    end

    def revert(set_state_with_method, context)
      Transition.new(
        "reverting => #{name}",
        from: to,
        to: from,
        state_machine: state_machine
      ).execute_with(context, set_state_with_method, nil)
    end

    def transitions_from_to?(from_state, to_state)
      from.in?(Array(from_state)) && to.in?(Array(to_state))
    end

    def id
      @id ||= "#{from}_#{to}"
    end

    private

    delegate :all_states, to: :state_machine

    attr_reader :block, :state_machine
    attr_accessor :block_proxy, :context

    def ensure_states_exist
      raise NxtStateMachine::Errors::UnknownStateError, "No state with :#{from} registered" unless state_machine.states.key?(from)
      raise NxtStateMachine::Errors::UnknownStateError, "No state with :#{to} registered" unless state_machine.states.key?(to)
    end
  end
end
