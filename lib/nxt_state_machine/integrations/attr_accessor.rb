module NxtStateMachine
  module AttrAccessor
    module ClassMethods
      def state_machine(name = :default, state: :state, target: nil, &config)
        machine = super(name, state: state, target: target, &config)

        machine.get_state_with do |target|
          if target.send(state).nil?
            target.send("#{state}=", initial_state.enum)
          end

          current_state = target.send(state)
          current_state&.to_sym
        end

        machine.set_state_with do |target, transition|
          transition.run_before_callbacks

          result = transition.execute do |block|
            block.call
            target.send("#{state}=", transition.to.enum)
          end

          if result
            transition.run_after_callbacks
            result
          else
            # abort transaction and reset state
            halt_transition
          end
        rescue StandardError => error
          target.send("#{state}=", transition.from.enum)

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
            target.send("#{state}=", transition.to.enum)
          end

          transition.run_after_callbacks

          result
        rescue StandardError
          target.send("#{state}=", transition.from.enum)
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
