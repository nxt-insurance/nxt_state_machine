module NxtStateMachine
  class Event::Names
    def self.build(name)
      [name, "#{name}!"].map(&:to_sym)
    end

    def self.set_state_method_map(name)
      build(name).zip([:set_state_with, :set_state_with!])
    end
  end
end
