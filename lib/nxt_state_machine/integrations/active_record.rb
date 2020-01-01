module NxtStateMachine
  module ActiveRecord
    module ClassMethods
      def state_machine(name = :default, state_attr: :state, target: nil, &config)
        machine = super(
          name,
          state_attr: state_attr,
          target: target,
          &config
        )

        machine.get_state_with do |target|
          if target
            if target.send(state_attr).nil? && target.new_record?
              target.assign_attributes(state_attr => machine.initial_state.to_s)
            end

            current_state = target.send(state_attr)
            current_state&.to_sym
          end
        end

        machine.set_state_with do |target, transition|
          target.transaction do
            transition.run_before_callbacks

            result = set_state(target, transition, state_attr, :save)

            if result
              transition.run_after_callbacks
              result
            else
              # abort transaction and reset state
              halt_transition
            end
          end
        rescue StandardError => error
          target.assign_attributes(state_attr => transition.from.to_s)

          if error.is_a?(NxtStateMachine::Errors::TransitionHalted)
            false
          else
            raise
          end
        end

        machine.set_state_with! do |target, transition|
          target.transaction do
            transition.run_before_callbacks
            result = set_state(target, transition, state_attr, :save!)
            transition.run_after_callbacks

            result
          end
        rescue StandardError
          target.assign_attributes(state_attr => transition.from.to_s)
          raise
        end

        machine
      end
    end

    module InstanceMethods
      private

      def set_state(target, transition, state_attr, method)
        transition.execute do |block|
          block.call
          target.assign_attributes(state_attr => transition.to.to_s)
          target.send(method)
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
