module NxtStateMachine
  class State
    def initialize(enum, state_machine, **opts)
      @enum = enum
      @state_machine = state_machine
      @initial = opts.delete(:initial)
      @transitions = []
      @options = opts.with_indifferent_access
      @index = opts.fetch(:index)
    end

    attr_accessor :enum, :initial, :index, :transitions, :state_machine, :options

    def to_s
      enum.to_s
    end

    def previous
      previous_index = (index - 1) % state_machine.states.size
      key = state_machine.states.keys[previous_index]
      state_machine.states.resolve(key)
    end

    def next
      next_index = (index + 1) % state_machine.states.size
      key = state_machine.states.keys[next_index]
      state_machine.states.resolve(key)
    end

    def last?
      index == state_machine.states.size - 1
    end

    def first?
      index == 0
    end
  end
end
