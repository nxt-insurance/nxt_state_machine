module NxtStateMachine
  class Transition::AroundCallbackChain

    def initialize(transition, context, state_machine)
      @transition = transition
      @context = context
      @state_machine = state_machine
    end

    def build(proxy)
      return proxy unless callbacks.any?

      callbacks.map { |c| Callable.new(c).with_context(context) }.reverse.inject(proxy) do |previous, callback|
        -> { callback.call(previous, transition) }
      end
    end

    private

    def callbacks
      @callbacks ||= state_machine.callbacks.resolve(transition).kind(:around)
    end

    attr_reader :transition, :context, :state_machine
  end
end
