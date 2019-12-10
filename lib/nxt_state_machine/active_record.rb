module NxtStateMachine
  module ActiveRecord
    module ClassMethods
      def active_record_state_machine(state:, scope: nil, &block)
        # TODO: Was this simply to add options that can be used in integrations?
        state_machine(state: state, scope: scope, &block)

        state_machine.get_state_with do
          @record ||= scope ? send(scope) : self

          if @record.send(state).nil? && @record.new_record?
            @record.assign_attributes(state => initial_state.name)
          end

          @record.send(state)
        end

        state_machine.set_state_with do |transition, context, callbacks|
          @record ||= scope ? send(scope) : self

          @record.transaction do
            state_machine.run_before_callbacks(transition, context)

            result = nil

            state_machine.execute_transition(transition, context) do
              transition.call
              @record.assign_attributes(state => transition.to)
              result = @record.save
            end

            if result
              state_machine.run_after_callbacks(transition, context)
              result
            else
              # reset state
              halt_transition
            end
          end
        rescue StandardError => error
          @record.assign_attributes(state => transition.from)

          if error.is_a?(NxtStateMachine::Errors::TransitionHalted)
            false
          else
            raise
          end
        end

        state_machine.set_state_with! do |transition, context, callbacks|
          @record ||= scope ? send(scope) : self

          @record.transaction do
            state_machine.run_before_callbacks(transition, context)

            result = nil

            state_machine.execute_transition(transition, context) do
              transition.call
              @record.assign_attributes(state => transition.to)
              result = @record.save!
            end

            state_machine.run_after_callbacks(transition, context)

            result
          end
        rescue StandardError
          @record.assign_attributes(state => transition.from)
          raise
        end
      end
    end

    def self.included(base)
      base.include(NxtStateMachine)
      base.extend(ClassMethods)
    end
  end
end
