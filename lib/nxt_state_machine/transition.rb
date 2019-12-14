module NxtStateMachine
  class Transition
    def initialize(name, from:, to:, state_machine:, &block)
      @name = name
      @from = StateEnum.new(state_machine, from)
      @to = StateEnum.new(state_machine, to)
      @state_machine = state_machine
      @block = block
      @context = nil
      @event = nil

      # TODO: Write a spec that verifies that transitions are unique
      ensure_states_exist
    end

    attr_reader :name, :from, :to

    # TODO: Probably would make sense if we could also define the event name to be passed in
    # => This way we could differentiate what event triggered the callback!!!

    # TODO: Prepare?
    # What if we would return a new object here: executable_transition - or transitions would be transition templates or so
    def execute_with(event, context, set_state_with_method, *args, **opts)
      # This exposes the transition block on the transition itself so it can be executed through transition.apply_block later in :set_state_with
      self.context = context
      self.event = event

      self.block_proxy = Proc.new do
        if block
          context.instance_exec(*args, **opts, &block)
        end
      end

      state_machine.send(set_state_with_method).with_context(context).call(self)
    end

    def apply_block
      block_proxy.call
    end

    def execute(&block)
      TransitionProxy.new(event, state_machine,self, context).call(&block)
    end

    alias_method :with_around_callbacks, :execute

    def run_before_callbacks
      state_machine.run_before_callbacks(self, context)
    end

    def run_after_callbacks
      state_machine.run_after_callbacks(self, context)
    end

    def transitions_from_to?(from_state, to_state)
      from.in?(Array(from_state).map(&:to_s)) && to.in?(Array(to_state).map(&:to_s))
    end

    def id
      @id ||= "#{from}_#{to}"
    end

    def from_state
      @from_state ||= state_machine.states.fetch(from)
    end

    def to_state
      @to_state ||= state_machine.states.fetch(to)
    end

    attr_reader :block_proxy, :event

    private

    delegate :all_states, to: :state_machine

    attr_reader :block, :state_machine
    attr_accessor :context
    attr_writer :block_proxy, :event

    def ensure_states_exist
      raise NxtStateMachine::Errors::UnknownStateError, "No state with :#{from} registered" unless state_machine.states.key?(from)
      raise NxtStateMachine::Errors::UnknownStateError, "No state with :#{to} registered" unless state_machine.states.key?(to)
    end
  end
end
