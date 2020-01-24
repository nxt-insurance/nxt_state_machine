module NxtStateMachine
  class State
    include Comparable

    def initialize(enum, state_machine, **opts)
      @enum = enum
      @state_machine = state_machine
      @initial = opts.delete(:initial)
      @transitions = []
      @options = opts.with_indifferent_access
      @index = opts.fetch(:index)

      ensure_index_not_occupied
    end

    attr_accessor :enum, :initial, :index, :transitions, :state_machine, :options

    def to_s
      enum.to_s
    end

    def previous
      current_index = sorted_states.index { |state| state.index == index }
      sorted_states[(current_index - 1) % sorted_states.size]
    end

    def next
      current_index = sorted_states.index { |state| state.index == index }
      sorted_states[(current_index + 1) % sorted_states.size]
    end

    def last?
      sorted_states.last.index == index
    end

    def first?
      sorted_states.first.index == index
    end

    def events
      state_machine.events_for_state(enum)
    end

    def <=>(other)
      index <=> other.index
    end

    private

    def sorted_states
      state_machine.states.values.sort_by(&:index)
    end

    def ensure_index_not_occupied
      state_with_same_index = state_machine.states.values.find { |state| state.index == index }
      return unless state_with_same_index

      raise StateWithSameIndexAlreadyRegistered, "The index #{index} is already occupied by state: #{state_with_same_index.enum}"
    end
  end
end
