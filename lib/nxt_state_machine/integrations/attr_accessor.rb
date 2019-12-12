module NxtStateMachine
  module AttrAccessor
    module ClassMethods
      def state_machine(state: :state, scope: nil, &config)
        @state_machine ||= begin
          machine = super(state: state, scope: scope, &config)

          machine.get_state_with do
            @subject ||= scope ? send(scope) : self

            if @subject.send(state).nil?
              @subject.send("#{state}=", initial_state.name)
            end

            @subject.send(state)
          end

          machine.set_state_with do |transition|
            @subject ||= scope ? send(scope) : self

            transition.run_before_callbacks

            result = transition.execute do |block|
              block.call
              @subject.send("#{state}=", transition.to)
            end

            if result
              transition.run_after_callbacks
              result
            else
              # abort transaction and reset state
              halt_transition
            end
          rescue StandardError => error
            @subject.send("#{state}=", transition.from)

            if error.is_a?(NxtStateMachine::Errors::TransitionHalted)
              false
            else
              raise
            end
          end

          machine.set_state_with! do |transition|
            @subject ||= scope ? send(scope) : self

            transition.run_before_callbacks

            result = transition.execute do |block|
              block.call
              @subject.send("#{state}=", transition.to)
            end

            transition.run_after_callbacks

            result
          rescue StandardError
            @subject.send("#{state}=", transition.from)
            raise
          end

          machine
        end
      end
    end

    def self.included(base)
      base.include(NxtStateMachine)
      base.extend(ClassMethods)
    end
  end
end
