module NxtStateMachine
  module ActiveRecord
    module ClassMethods
      def state_machine(name = :default, state: :state, scope: nil, &config)
        @state_machines ||= Registry.new(:state_machines)
        @state_machines[name] ||= begin
          machine = StateMachine.new(name, self, event_registry, { state: state, scope: scope }).configure(&config)

          machine.get_state_with do
            records[name] ||= scope ? send(scope) : self

            if records[name]
              if records[name].send(state).nil? && records[name].new_record?
                records[name].assign_attributes(state => initial_state.name)
              end

              records[name].send(state)
            end
          end

          machine.set_state_with do |transition|
            records[name] ||= scope ? send(scope) : self

            records[name].transaction do
              transition.run_before_callbacks

              result = transition.execute do |block|
                block.call
                records[name].assign_attributes(state => transition.to)
                records[name].save
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
            records[name].assign_attributes(state => transition.from)

            if error.is_a?(NxtStateMachine::Errors::TransitionHalted)
              false
            else
              raise
            end
          end

          machine.set_state_with! do |transition|
            records[name] ||= scope ? send(scope) : self

            records[name].transaction do
              transition.run_before_callbacks

              result = transition.execute do |block|
                block.call
                records[name].assign_attributes(state => transition.to)
                records[name].save!
              end

              transition.run_after_callbacks

              result
            end
          rescue StandardError
            records[name].assign_attributes(state => transition.from)
            raise
          end

          machine
        end
      end
    end

    module InstanceMethods
      def records
        @records ||= {}
      end
    end

    def self.included(base)
      base.include(NxtStateMachine)
      base.extend(ClassMethods)
      base.include(InstanceMethods)
    end
  end
end
