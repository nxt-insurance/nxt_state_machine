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

        state_machine.set_state_with do |transition, context, callbacks|
          @record ||= scope ? send(scope) : self

          @record.transaction do
            callbacks[:before].each { |callback| Callable.new(callback).with_context(self).call }

            result = nil

            proxy = Proc.new do
              transition.call
              @record.assign_attributes(state => transition.to)
              result = @record.save
            end

            # Can we build the callback chain before?
            if callbacks[:around].any?
              around_callbacks = callbacks[:around].map { |c| Callable.new(c).with_context(context) }

              around_callback_chain = around_callbacks.reverse.inject(proxy) do |previous, callback|
                -> { callback.call(previous) }
              end

              around_callback_chain.call
            else
              proxy.call
            end

            if result
              callbacks[:after].each { |callback| Callable.new(callback).with_context(self).call }
              result
            else
              # reset state
              @record.assign_attributes(state => transition.from)
              halt_transaction
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
            callbacks[:before].each { |callback| Callable.new(callback).with_context(self).call }

            result = nil

            proxy = Proc.new do
              transition.call
              @record.assign_attributes(state => transition.to)
              result = @record.save!
            end

            if callbacks[:around].any?
              around_callbacks = callbacks[:around].map { |c| Callable.new(c).with_context(context) }

              around_callback_chain = around_callbacks.reverse.inject(proxy) do |previous, callback|
                -> { callback.call(previous) }
              end

              around_callback_chain.call
            else
              proxy.call
            end

            callbacks[:after].each { |callback| Callable.new(callback).with_context(self).call }

            result
          end
        rescue StandardError
          @record.assign_attributes(state => transition.from)
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
