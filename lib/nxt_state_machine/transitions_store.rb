module NxtStateMachine
  class TransitionsStore < Array
    def <<(value)
      if find { |item| item.from == value.from && item.to == item.to }
        raise NxtStateMachine::Errors::TransitionAlreadyRegistered,
              "A transition from :#{value.from} to :#{value.to} was already registered"
      end

      super
    end
  end
end
