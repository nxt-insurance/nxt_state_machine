module NxtStateMachine
  class StateEnum < String
    def initialize(state_machine, string)
      super(string.to_s)
      @state_machine = state_machine
      state
      freeze
    end

    def state
      @state ||= state_machine.states.fetch(self)
    end

    def eql?(other)
      self == other.to_s
    end

    private

    attr_reader :state_machine
  end
end
