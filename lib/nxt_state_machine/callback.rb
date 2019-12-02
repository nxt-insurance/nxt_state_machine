module NxtStateMachine
  class Callback
    def initialize(method_or_block)
      @method_or_block = method_or_block
    end

    def run(context, *args)
      if method_or_block.is_a?(Symbol)
        context.send(method_or_block)
      elsif method_or_block.respond_to?(:call)
        context.instance_exec(*args, &method_or_block)
      else
        raise NxtStateMachine::Errors::InvalidCallbackOption, "Don't know how to deal with: #{method_or_block}"
      end
    end

    private

    attr_reader :method_or_block
  end
end
