module NxtStateMachine
  class Transition::Store < Array
    def <<(transition)
      ensure_transition_unique(transition)
      super
    end

    alias_method :add, :<<

    private

    def ensure_transition_unique(transition)
      return unless find { |other| other.from.enum == transition.from.enum && other.to.enum == transition.to.enum }

      raise NxtStateMachine::Errors::TransitionAlreadyRegistered,
            "A transition from :#{transition.from.enum} to :#{transition.to.enum} was already registered"
    end
  end
end
