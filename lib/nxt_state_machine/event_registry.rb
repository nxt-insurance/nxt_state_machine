module NxtStateMachine
  class EventRegistry < NxtRegistry::Registry
    def initialize
      super :events
      self.on_key_already_registered = ->(key) do
        raise NxtStateMachine::Errors::EventAlreadyRegistered, "An event with the name '#{key}' was already registered!"
      end
    end
  end
end
