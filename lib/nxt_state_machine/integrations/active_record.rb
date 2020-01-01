module NxtStateMachine
  module ActiveRecord
    module ClassMethods
      def state_machine(name = :default, state: :state, target: nil, &config)
        machine = super(
          name,
          state: state,
          target: target,
          &config
        )

        machine.get_state_with do |target|
          if target
            if target.send(state).nil? && target.new_record?
              target.assign_attributes(state => machine.initial_state.to_s)
            end

            current_state = target.send(state)
            current_state&.to_sym
          end
        end

        machine.set_state_with do |target, transition|
          target.transaction do
            transition.run_before_callbacks

            result = transition.execute do |block|
              block.call
              target.assign_attributes(state => transition.to.to_s)
              target.save
            end

            if result
              transition.run_after_callbacks
              result
            else
              # abort transaction and reset state
              halt_transition
            end
          end
        rescue StandardError => error
          target.assign_attributes(state => transition.from.to_s)

          if error.is_a?(NxtStateMachine::Errors::TransitionHalted)
            false
          else
            raise
          end
        end

        machine.set_state_with! do |target, transition|
          target.transaction do
            transition.run_before_callbacks

            result = transition.execute do |block|
              block.call
              target.assign_attributes(state => transition.to.to_s)
              target.save!
            end

            transition.run_after_callbacks

            result
          end
        rescue StandardError
          target.assign_attributes(state => transition.from.to_s)
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
