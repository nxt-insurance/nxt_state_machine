module NxtStateMachine
  module ActiveRecord
    module ClassMethods
      def state_machine(name = :default, state: :state, scope: nil, &config)
        machine = super(
          name,
          state: state,
          scope: scope,
          &config
        )

        machine.get_state_with do
          state_machine_targets[name] ||= scope ? send(scope) : self

          if state_machine_targets[name]
            if state_machine_targets[name].send(state).nil? && state_machine_targets[name].new_record?
              state_machine_targets[name].assign_attributes(state => machine.initial_state.to_s)
            end

            current_state = state_machine_targets[name].send(state)
            current_state&.to_sym
          end
        end

        machine.set_state_with do |transition|
          state_machine_targets[name] ||= scope ? send(scope) : self

          state_machine_targets[name].transaction do
            transition.run_before_callbacks

            result = transition.execute do |block|
              block.call

              state_machine_targets[name].assign_attributes(state => transition.to.to_s)
              state_machine_targets[name].save
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
          state_machine_targets[name].assign_attributes(state => transition.from.to_s)

          if error.is_a?(NxtStateMachine::Errors::TransitionHalted)
            false
          else
            raise
          end
        end

        machine.set_state_with! do |transition|
          state_machine_targets[name] ||= scope ? send(scope) : self

          state_machine_targets[name].transaction do
            transition.run_before_callbacks

            result = transition.execute do |block|
              block.call
              state_machine_targets[name].assign_attributes(state => transition.to.to_s)
              state_machine_targets[name].save!
            end

            transition.run_after_callbacks

            result
          end
        rescue StandardError
          state_machine_targets[name].assign_attributes(state => transition.from.to_s)
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
