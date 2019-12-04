module NxtStateMachine
  class CallCenter
    def initialize(callee, context: nil)
      @callee = callee
      @context = context
    end

    def call(*args, **opts)
      args << [opts]
      args = args.take(arity)

      if context
        if callee.is_a?(Symbol)
          context.send(callee, *args)
        else
          context.instance_exec(*args, &callee)
        end
      else
        callee.call(*args)
      end
    end

    private

    attr_reader :callee, :context

    delegate :arity, to: :callee
  end
end
