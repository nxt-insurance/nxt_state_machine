module NxtStateMachine
  module Errors
    class TransitionHalted < Error
      def initialize(*args, **opts)
        super(*args)
        @options = opts
      end

      attr_reader :options
    end
  end
end
