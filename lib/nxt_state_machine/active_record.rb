module NxtStateMachine
  module ActiveRecord

    module ClassMethods
      def active_record_state_machine(state:, scope: nil, &block)
        state_machine(state: state, scope: scope, &block)

        state_machine.get_state_with do
          record = scope ? send(scope) : self
          record.assign_attributes(state => initial_state.name) if record.new_record?
          record.send(state)
        end

        state_machine.set_state_with do |from, to, transition, callbacks|
          record = scope ? send(scope) : self

          record.transaction do
            callbacks[:before].each { |callback| callback.run(self) }

            transition.call
            record.assign_attributes(state => to)

            result = record.save

            if result
              callbacks[:after].each { |callback| callback.run(self) }
              result
            else
              # reset state
              record.assign_attributes(state => from)
            end
          end
        end

        state_machine.set_state_with! do |from, to, transition, callbacks|
          record = scope ? send(scope) : self

          record.transaction do
            callbacks[:before].each { |callback| callback.run(self) }

            transition.call
            record.assign_attributes(state => to)

            begin
              record.save!
              callbacks[:after].each { |callback| callback.run(self) }
            rescue ::ActiveRecord::RecordInvalid, ActiveRecord::Rollback => e
              record.assign_attributes(state => from)
              raise
            end
          end
        end
      end
    end

    def self.included(base)
      base.include(NxtStateMachine)
      base.extend(ClassMethods)
    end
  end
end
