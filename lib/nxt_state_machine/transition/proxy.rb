module NxtStateMachine
  class Transition::Proxy
    def initialize(event, state_machine, transition, context)
      @event = event
      @transition = transition
      @state_machine = state_machine
      @context = context
    end

    def call(&block)
      proxy = if block.arity == 1
        Proc.new do
          block.call(transition.block)
        end
      else
        block
      end

      around_callback_chain(proxy).call
    end

    private

    def around_callback_chain(proxy)
      @around_callback_chain ||= Transition::AroundCallbackChain.new(transition, context, state_machine).build(proxy)
    end

    attr_reader :proxy, :transition, :state_machine, :context, :event
  end
end

