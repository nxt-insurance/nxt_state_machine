module NxtStateMachine
  class Transition
    def initialize(name, from:, to:, state_machine:, &block)
      @name = name
      @from = from
      @to = to
      @state_machine = state_machine
      @block = block

      # TODO: Write a spec that verifies that transitions are unique
      ensure_states_exist
    end

    attr_reader :name, :from, :to

    # TODO: Probably would make sense if we could also define the event name to be passed in
    # => This way we could differentiate what event triggered the callback!!!
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

    def transitions_from_to?(from_state, to_state)
      from.in?(Array(from_state)) && to.in?(Array(to_state))
    end

    def id
      @id ||= "#{from}_#{to}"
    end

    private

    delegate :all_states, to: :state_machine

    attr_reader :block, :state_machine
    attr_accessor :executor

    def ensure_states_exist
      raise NxtStateMachine::Errors::UnknownStateError, "No state with :#{from} registered" unless state_machine.states.key?(from)
      raise NxtStateMachine::Errors::UnknownStateError, "No state with :#{to} registered" unless state_machine.states.key?(to)
    end
  end
end
