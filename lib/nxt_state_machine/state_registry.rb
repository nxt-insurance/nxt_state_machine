module NxtStateMachine
  class StateRegistry < NxtRegistry::Registry
    def initialize
      super :states do
        on_key_already_registered do |key|
          raise NxtStateMachine::Errors::StateAlreadyRegistered,
                "A state with the name '#{key}' was already registered!"
        end
      end
    end
  end
end
