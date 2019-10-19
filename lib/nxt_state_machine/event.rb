module NxtStateMachine
  class Event
    def initialize(name, from:, to:, &block)
      @name = name
      @from = from
      @to = to
      @action = block
    end

    attr_reader :name, :from, :to, :action

    def execute(target)
      return unless action
      target.instance_exec(&action)
    end
  end
end
