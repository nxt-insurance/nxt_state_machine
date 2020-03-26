module NxtStateMachine
  module AttrAccessor
    module ClassMethods
      def state_machine(name = :default, state_attr: :state, target: nil, &config)
        machine = super(
          name,
          state_attr: state_attr,
          target: target,
          &config
        )

        machine.get_state_with do |target|
          if target.send(state_attr).nil?
            target.send("#{state_attr}=", initial_state.enum)
          end

          target.send(state_attr)
        end

        machine.set_state_with do |target, transition|
          transition.run_before_callbacks
          result = set_state(target, transition, state_attr)
          transition.run_after_callbacks

          transition.run_success_callbacks || result
        rescue StandardError => error
          target.send("#{state_attr}=", transition.from.enum)

          if error.is_a?(NxtStateMachine::Errors::TransitionHalted)
            false
          else
            raise
          end
        end

        machine.set_state_with! do |target, transition|
          transition.run_before_callbacks
          result = set_state(target, transition, state_attr)
          transition.run_after_callbacks

          transition.run_success_callbacks || result
        rescue StandardError
          target.send("#{state_attr}=", transition.from.enum)
          raise
        end

        machine
      end
    end

    module InstanceMethods
      private

      def set_state(target, transition, state_attr)
        transition.execute do |block|
          result = block ? block.call : nil
          set_state_result = target.send("#{state_attr}=", transition.to.enum)
          block ? result : set_state_result
        end
      end
    end

    def self.included(base)
      base.include(NxtStateMachine)
      base.include(InstanceMethods)
      base.extend(ClassMethods)
    end
  end
end
