module NxtStateMachine
  class Transition
    def initialize(name, from:, to:, &block)
      @name = name
      @from = from
      @to = to
      @block = block
    end

    attr_reader :block

    def execute(context, **opts)
      context.instance_exec(**opts, &block)
    end

    # check if transition is possible
  end
end
