module NxtStateMachine
  class Transition
    module Interface
      def id
        @id ||= "#{from.to_s}_#{to.to_s}"
      end

      def transitions_from_to?(from_state, to_state)
        from.enum.in?(Array(from_state)) && to.enum.in?(Array(to_state))
      end

      delegate :all_states, :any_states, to: :state_machine
    end
  end
end
