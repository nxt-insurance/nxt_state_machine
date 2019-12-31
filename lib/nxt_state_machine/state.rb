module NxtStateMachine
  class State
    def initialize(enum, machine, **opts)
      @enum = enum
      @machine = machine
      @initial = opts.delete(:initial)
      @transitions = []
      @options = opts.with_indifferent_access
    end

    attr_accessor :enum, :initial, :transitions, :machine, :options

    def to_s
      enum.to_s
    end
  end
end
