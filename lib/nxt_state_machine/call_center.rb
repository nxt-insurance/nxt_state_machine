module NxtStateMachine
  class CallCenter
    def initialize(callee)
      @callee = callee
      @context = nil
    end

    def with_context(context)
      self.context = context
      self
    end

    def call(*args, **opts)
      if context
        if callee.is_a?(Symbol)
          # in the context of a method this works for a fix amount of arguments only
          method = context.send(:method, callee)
          arity = method.arity
          args << opts
          args = args.take(arity)
          context.send(callee, *args)
        else
          args << opts
          args = args.take(callee.arity)
          context.instance_exec(*args, &callee)
        end
      else
        callee.call(*args)
      end
    end

    private

    attr_accessor :callee, :context
  end
end
