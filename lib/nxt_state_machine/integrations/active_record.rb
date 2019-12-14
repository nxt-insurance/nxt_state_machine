module NxtStateMachine
  module ActiveRecord
    module ClassMethods
      def state_machine(name = :default, state: :state, scope: nil, &config)
        @state_machines ||= Registry.new(:state_machines)
        @state_machines[name] ||= begin
          machine = StateMachine.new(
            name,
            self,
            event_registry,
            state: state, scope: scope
          ).configure(&config)

          machine.get_state_with do
            state_machine_targets[name] ||= scope ? send(scope) : self

            if state_machine_targets[name]
              if state_machine_targets[name].send(state).nil? && state_machine_targets[name].new_record?
                state_machine_targets[name].assign_attributes(state => machine.initial_state.to_s)
              end

              state_machine_targets[name].send(state)
            end
          end

          machine.set_state_with do |transition|
            state_machine_targets[name] ||= scope ? send(scope) : self

            state_machine_targets[name].transaction do
              transition.run_before_callbacks

              result = transition.execute do |block|
                block.call
                state_machine_targets[name].assign_attributes(state => transition.to)
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
            state_machine_targets[name].assign_attributes(state => transition.from)

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
                state_machine_targets[name].assign_attributes(state => transition.to)
                state_machine_targets[name].save!
              end

              transition.run_after_callbacks

              result
            end
          rescue StandardError
            state_machine_targets[name].assign_attributes(state => transition.from)
            raise
          end

          machine
        end
      end
    end

    module InstanceMethods
      private

      def state_machine_targets
        @state_machine_targets ||= {}
      end
    end

    def self.included(base)
      base.include(InstanceMethods)
      base.include(NxtStateMachine)
      base.extend(ClassMethods)
    end
  end
end
