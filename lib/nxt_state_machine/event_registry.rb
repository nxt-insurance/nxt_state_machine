module NxtStateMachine
  class EventRegistry < Registry
    def initialize
      super(
        :events,
        on_key_occupied: Proc.new do |key|
          raise NxtStateMachine::Errors::EventAlreadyRegistered,
          "An event with the name '#{key}' was already registered!"
        end
      )
    end
  end
end
