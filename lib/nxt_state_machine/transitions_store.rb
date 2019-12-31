module NxtStateMachine
  class TransitionsStore < Array
    def <<(transition)
      if find { |item| item.from.enum == transition.from.enum && item.to.enum == transition.to.enum }
        raise NxtStateMachine::Errors::TransitionAlreadyRegistered,
              "A transition from :#{transition.from.enum} to :#{transition.to.enum} was already registered"
      end

      super
    end
  end
end
