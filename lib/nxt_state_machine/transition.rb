module NxtStateMachine
  class Transition
    def initialize(name, from:, to:, state_machine:, &block)
      @name = name
      @from = state_machine.states.resolve(from)
      @to = state_machine.states.resolve(to)
      @state_machine = state_machine
      @block = block

      # TODO: Write a spec that verifies that transitions are unique
      ensure_states_exist
    end

    attr_reader :name, :from, :to

    # TODO: Probably would make sense if we could also define the event name to be passed in
    # => This way we could differentiate what event triggered the callback!!!

    # TODO: Prepare?
    # What if we would return a new object here: executable_transition - or transitions would be transition templates or so
    def execute_with(event, context, set_state_with_method, *args, **opts)
      # This exposes the transition block on the transition itself so it can be executed through later in :set_state_with
      self.context = context
      self.event = event

      self.block_proxy = Proc.new do
        if block
          # if the block takes arguments we always pass the transition as the first one
          args.prepend(self) if block.arity > 0
          context.instance_exec(*args, **opts, &block)
        end
      end

      state_machine.send(set_state_with_method).with_context(context).call(state_machine.target(context), self)
    end

    def apply_block
      block_proxy.call
    end

    def execute(&block)
      TransitionProxy.new(event, state_machine,self, context).call(&block)
    rescue StandardError => error
      callback = state_machine.find_error_callback(error, self)
      raise unless callback

      Callable.new(callback).with_context(context).call(error, self)
    end

    alias_method :with_around_callbacks, :execute

    def run_before_callbacks
      state_machine.run_before_callbacks(self, context)
    end

    def run_after_callbacks
      state_machine.run_after_callbacks(self, context)
    end

    def transitions_from_to?(from_state, to_state)
      from.enum.in?(Array(from_state)) && to.enum.in?(Array(to_state))
    end

    def id
      @id ||= "#{from.to_s}_#{to.to_s}"
    end

    attr_reader :block_proxy, :event

    private

    delegate :all_states, to: :state_machine

    attr_reader :block, :state_machine
    attr_accessor :context
    attr_writer :block_proxy, :event

    def ensure_states_exist
      raise NxtStateMachine::Errors::UnknownStateError, "No state with :#{from} registered" unless state_machine.states.key?(from.enum)
      raise NxtStateMachine::Errors::UnknownStateError, "No state with :#{to} registered" unless state_machine.states.key?(to.enum)
    end
  end
end
