module NxtStateMachine
  class Transition::Factory
    include Transition::Interface

    def initialize(name, from:, to:, state_machine:, &block)
      @name = name
      @from = state_machine.states.resolve!(from)
      @to = state_machine.states.resolve!(to)
      @state_machine = state_machine
      @block = block

      # TODO: Write a spec that verifies that transitions are unique
      ensure_states_exist
    end

    attr_reader :name, :from, :to

    # TODO: Probably would make sense if we could also define the event name to be passed in
    # => This way we could differentiate what event triggered the callback!!!

    def build_transition(event, context, set_state_method, *args, **opts)
      options = {
        from: from,
        to: to,
        state_machine: state_machine,
        context: context,
        event: event,
        set_state_method: set_state_method,
        arguments: args,
        options: opts
      }

      transition = Transition.new(event.name, **options)

      if block
        # if the transition takes a block we make it available through a proxy on the transition itself!
        transition.send(:block=, Proc.new do
          # if the transition block takes arguments we always pass the transition itself as the first argument
          # callbacks also get passed the transition object in case they take an argument and can access args and
          # options passed to the transition when invoked through that transition object
          if block.arity > 0
            args = [transition] + args
          end
          context.instance_exec(*args, **opts, &block)
        end)
      end

      transition.trigger
    end

    private

    delegate :all_states, :any_states, to: :state_machine

    attr_reader :block, :state_machine

    def ensure_states_exist
      raise NxtStateMachine::Errors::UnknownStateError, "No state with :#{from} registered" unless state_machine.states.key?(from.enum)
      raise NxtStateMachine::Errors::UnknownStateError, "No state with :#{to} registered" unless state_machine.states.key?(to.enum)
    end
  end
end
