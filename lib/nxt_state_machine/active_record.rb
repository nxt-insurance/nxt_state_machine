module NxtStateMachine
  module ActiveRecord
    module ClassMethods
      def state_machine(state: :state, scope: nil, &config)
        @state_machine ||= begin
          state_machine = define_state_machine(state: state, scope: scope, &config)

          state_machine.get_state_with do
            @record ||= scope ? send(scope) : self

            if @record.send(state).nil? && @record.new_record?
              @record.assign_attributes(state => initial_state.name)
            end

            @record.send(state)
          end

          state_machine.set_state_with do |transition|
            @record ||= scope ? send(scope) : self

            @record.transaction do
              transition.run_before_callbacks

              result = transition.execute do |block|
                block.call
                @record.assign_attributes(state => transition.to)
                @record.save
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
            @record.assign_attributes(state => transition.from)

            if error.is_a?(NxtStateMachine::Errors::TransitionHalted)
              false
            else
              raise
            end
          end

          state_machine.set_state_with! do |transition|
            @record ||= scope ? send(scope) : self

            @record.transaction do
              transition.run_before_callbacks

              result = transition.execute do |block|
                block.call
                @record.assign_attributes(state => transition.to)
                @record.save!
              end

              transition.run_after_callbacks

              result
            end
          rescue StandardError
            @record.assign_attributes(state => transition.from)
            raise
          end

          state_machine
        end
      end
    end

    def self.included(base)
      base.include(NxtStateMachine)
      base.extend(ClassMethods)
    end
  end
end
