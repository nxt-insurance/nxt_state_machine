module NxtStateMachine
  class Transition
    def initialize(name, from:, to:, state_machine:, &block)
      @name = name
      @from = from
      @to = to
      @state_machine = state_machine
      @block = block

      ensure_states_exist
    end

    attr_reader :name, :from, :to, :block, :state_machine

    def execute(context, *args, **opts)
      transition = lambda do
        if block
          context.instance_exec(*args, **opts, &block)
        end
      end

      context.instance_exec(from, to, transition, &state_machine.set_state_with)
      # state_machine.current_state = state_machine.states.fetch(to)
    end

    def ensure_states_exist
      raise NxtStateMachine::Errors::UnknownStateError, "No state with :#{from} registered" unless state_machine.states.key?(from)
      raise NxtStateMachine::Errors::UnknownStateError, "No state with :#{to} registered" unless state_machine.states.key?(to)
    end
  end
end
