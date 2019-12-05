module NxtStateMachine
  module ActiveRecord

    module ClassMethods
      def active_record_state_machine(state:, scope: nil, &block)
        # TODO: Why do we pass state and scope to the state_machine here?
        # Is it even aware of that, or does it just end up in options for no reason?
        state_machine(state: state, scope: scope, &block)

        state_machine.get_state_with do
          @record ||= scope ? send(scope) : self

          if @record.send(state).nil? && @record.new_record?
            @record.assign_attributes(state => initial_state.name)
          end

          @record.send(state)
        end

        state_machine.set_state_with do |from, to, transition, callbacks|
          @record ||= scope ? send(scope) : self

          @record.transaction do
            callbacks[:before].each { |callback| callback.run(self) }

            result = nil

            proxy = Proc.new do
              transition.call
              @record.assign_attributes(state => to)
              result = @record.save
            end

            proxy.call

            if result
              callbacks[:after].each { |callback| callback.run(self) }
              result
            else
              # reset state
              @record.assign_attributes(state => from)
              halt_transaction
            end
          end
        rescue StandardError => error # TODO: we should probably only rescue from known exceptions (AR, TransitionHalted)
          @record.assign_attributes(state => from)

          if error.is_a?(NxtStateMachine::Errors::TransitionHalted)
            false
          else
            raise
          end
        end

        state_machine.set_state_with! do |from, to, transition, callbacks|
          @record ||= scope ? send(scope) : self

          @record.transaction do
            callbacks[:before].each { |callback| callback.run(self) }

            proxy = Proc.new do
              transition.call
              @record.assign_attributes(state => to)
              @record.save!
            end

            proxy.call

            callbacks[:after].each { |callback| callback.run(self) }
          end
        rescue StandardError
          @record.assign_attributes(state => from)
          raise
        end
      end
    end

    module InstanceMethods
      def halt_transaction(*args, **opts)
        raise NxtStateMachine::Errors::TransitionHalted.new(*args, **opts)
      end
    end

    def self.included(base)
      base.include(NxtStateMachine)
      base.include(InstanceMethods)
      base.extend(ClassMethods)
    end
  end
end
