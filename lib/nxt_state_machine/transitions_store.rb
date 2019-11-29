module NxtStateMachine
  class TransitionsStore < Array
    def <<(transition)
      if find { |item| item.from == transition.from && item.to == transition.to }
        raise NxtStateMachine::Errors::TransitionAlreadyRegistered,
              "A transition from :#{transition.from} to :#{transition.to} was already registered"
      end

      super
    end
  end
end
