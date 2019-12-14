module NxtStateMachine
  class State
    def initialize(name, **opts)
      @name = name.to_s
      @initial = opts.delete(:initial)
      @transitions = []
      @options = opts.with_indifferent_access
    end

    attr_accessor :name, :initial, :transitions, :options

    def to_s
      name
    end
  end
end
