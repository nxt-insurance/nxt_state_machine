module NxtStateMachine
  class Transition
    include Transition::Interface

    def initialize(name, event:, from:, to:, state_machine:, context:, set_state_method:, &block)
      @name = name
      @event = event
      @from = state_machine.states.resolve(from)
      @to = state_machine.states.resolve(to)
      @state_machine = state_machine
      @set_state_method = set_state_method
      @context = context
      @block = block
    end

    attr_reader :name, :from, :to, :block, :event

    # This triggers the set state method
    def trigger
      Callable.new(
        state_machine.send(set_state_method)
      ).bind(
        context
      ).call(state_machine.target(context), self)
    rescue StandardError => error
      callback = state_machine.find_error_callback(error, self)
      raise unless callback

      Callable.new(callback).bind(context).call(error, self)
    end

    # This must be used in set_state method to actually execute the transition within the around callback chain
    def execute(&block)
      Transition::Proxy.new(event, state_machine,self, context).call(&block)
    end

    alias_method :with_around_callbacks, :execute

    def run_before_callbacks
      state_machine.run_before_callbacks(self, context)
    end

    def run_after_callbacks
      state_machine.run_after_callbacks(self, context)
    end

    private

    attr_reader :state_machine, :set_state_method, :context
    attr_writer :block
  end
end
