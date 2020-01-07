module NxtStateMachine
  class Callable
    def initialize(callee)
      @callee = callee

      if callee.is_a?(Symbol)
        self.type = :method
      elsif callee.respond_to?(:call)
        self.type = :proc
        self.context = callee.binding
      else
        raise ArgumentError, "Callee is nor symbol nor a proc: #{callee}"
      end
    end

    def bind(execution_context = nil)
      self.context = execution_context
      ensure_context_not_missing
      self
    end

    # NOTE: allowing call(*args, **opts) is dangerous when called with a hash as an argument!
    # It will automatically become the **opts which might not be what you want! Probably better
    # to introduce arguments: [], options: { } or something
    def call(*args)
      ensure_context_not_missing

      args = args.take(arity)

      if method?
        context.send(callee, *args)
      else
        context.instance_exec(*args, &callee)
      end
    end

    def arity
      if proc?
        callee.arity
      elsif method?
        method = context.send(:method, callee)
        method.arity
      else
        raise ArgumentError, "Can't resolve arity from #{callee}"
      end
    end

    private

    def proc?
      type == :proc
    end

    def method?
      type == :method
    end

    def ensure_context_not_missing
      return if context
      raise ArgumentError, "Missing context: #{context}"
    end

    attr_accessor :context, :callee, :type
  end
end
