module NxtStateMachine
  module Errors
    Error = Class.new(StandardError)
    EventAlreadyRegistered = Class.new(Error)
    StateAlreadyRegistered = Class.new(Error)
    TransitionAlreadyRegistered = Class.new(Error)
    UnknownStateError = Class.new(Error)
    EventWithoutTransitions = Class.new(Error)
    InitialStateAlreadySet = Class.new(Error)
    TransitionNotDefined = Class.new(Error)
    MissingConfiguration = Class.new(Error)
    InvalidCallbackOption = Class.new(Error)
  end
end
