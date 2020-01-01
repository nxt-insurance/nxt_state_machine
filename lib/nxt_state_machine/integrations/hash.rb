module NxtStateMachine
  module Hash
    module ClassMethods
      def state_machine(name = :default, state_attr: :state, target: nil, &config)
        machine = super(
          name,
          state_attr: state_attr,
          target: target,
          &config
        )

        machine.get_state_with do |target|
          if target[state_attr].nil?
            target[state_attr] = initial_state.enum
          end

          current_state = target[state_attr]
          current_state&.to_sym
        end

        machine.set_state_with do |target, transition|
          transition.run_before_callbacks

          result = transition.execute do |block|
            block.call
            target[state_attr] = transition.to.enum
          end

          if result
            transition.run_after_callbacks
            result
          else
            # abort transaction and reset state
            halt_transition
          end
        rescue StandardError => error
          target[state_attr] = transition.from.enum

          if error.is_a?(NxtStateMachine::Errors::TransitionHalted)
            false
          else
            raise
          end
        end

        machine.set_state_with! do |target, transition|
          transition.run_before_callbacks

          result = transition.execute do |block|
            block.call
            target[state_attr] = transition.to.enum
          end

          transition.run_after_callbacks

          result
        rescue StandardError
          target[state_attr] = transition.from.enum
          raise
        end

        machine
      end
    end

    def self.included(base)
      base.include(NxtStateMachine)
      base.extend(ClassMethods)
    end
  end
end
