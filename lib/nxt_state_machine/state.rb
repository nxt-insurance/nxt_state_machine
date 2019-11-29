module NxtStateMachine
  class State
    def initialize(name, initial:)
      @name = name
      @initial = initial
      @transitions = []
    end

    attr_accessor :name, :initial, :transitions

    def to_s
      name
    end
  end
end
