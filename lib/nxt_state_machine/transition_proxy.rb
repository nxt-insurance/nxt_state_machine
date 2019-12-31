module NxtStateMachine
  class TransitionProxy
    def initialize(event, state_machine, transition, context)
      @event = event
      @transition = transition
      @state_machine = state_machine
      @context = context
    end

    def call(&block)
      proxy = if block.arity == 1
        Proc.new do
          block.call(transition.block_proxy)
        end
      else
        block
      end

      if around_callbacks.any?
        around_callback_chain(proxy).call
      else
        proxy.call
      end
    end

    private

    def around_callback_chain(proxy)
      around_callbacks.map { |c| Callable.new(c).with_context(context) }.reverse.inject(proxy) do |previous, callback|
        -> { callback.call(previous, transition) }
      end
    end

    def around_callbacks
      @around_callbacks ||= state_machine.callbacks.resolve(transition).kind(:around)
    end

    attr_reader :proxy, :transition, :state_machine, :context, :event
  end
end

