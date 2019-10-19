module NxtStateMachine
  class Transition
    def initialize(from, to)
      @from = from
      @to = to
    end

    attr_reader :from, :to

    def key
      "#{from}_#{to}"
    end
  end
end
