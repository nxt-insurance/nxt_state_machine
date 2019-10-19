module NxtStateMachine
  class State
    def initialize(name, guard = nil)
      @name = name
      @guard = guard
    end
  end
end
