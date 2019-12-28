module NxtStateMachine
  class EventRegistry < NxtRegistry::Registry
    def initialize
      super :events do
        on_key_already_registered do |key|
          raise NxtStateMachine::Errors::EventAlreadyRegistered, "An event with the name '#{key}' was already registered!"
        end
      end
    end
  end
end
