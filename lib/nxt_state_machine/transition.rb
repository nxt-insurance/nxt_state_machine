module NxtStateMachine
  class Transition
    def initialize(name, from:, to:, state_machine:, &block)
      @name = name
      @from = from
      @to = to
      @state_machine = state_machine
      @block = block

      # TODO: Should we also check here that this is unique and was not defined yet?!
      ensure_states_exist
    end

    attr_reader :name, :from, :to

    def execute(context, set_state_with, callbacks = nil, *args, **opts)
      # This exposes the transition block on the transition itself so it can be executed through :call later below
      self.executor = Proc.new do
        if block
          context.instance_exec(*args, **opts, &block)
        end
      end

      set_state_with.with_context(context).call(self, context, callbacks)
    end

    def call
      executor.call
    end

    private

    attr_reader :block, :state_machine
    attr_accessor :executor

    def ensure_states_exist
      raise NxtStateMachine::Errors::UnknownStateError, "No state with :#{from} registered" unless state_machine.states.key?(from)
      raise NxtStateMachine::Errors::UnknownStateError, "No state with :#{to} registered" unless state_machine.states.key?(to)
    end
  end
end
