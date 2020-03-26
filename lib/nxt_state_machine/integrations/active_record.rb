module NxtStateMachine
  module ActiveRecord
    module ClassMethods
      def state_machine(name = :default, state_attr: :state, target: nil, &config)
        machine = super(
          name,
          state_attr: state_attr,
          target: target,
          &config
        )

        machine.get_state_with do |target|
          if target
            if target.send(state_attr).nil? && target.new_record?
              target.assign_attributes(state_attr => machine.initial_state.to_s)
            end

            current_state = target.send(state_attr)
            current_state&.to_sym
          end
        end

        machine.set_state_with do |target, transition|
          set_state(machine, target, transition, state_attr, :save)
        end

        machine.set_state_with! do |target, transition|
          set_state(machine, target, transition, state_attr, :save!)
        end

        machine.define_singleton_method :add_state_methods_to_model do |model_class|
          model_class.class_eval do
            machine.states.keys.each do |state_name|
              define_method "#{state_name}?" do
                send(machine.options.fetch(:state_attr)) == state_name
              end
            end
          end
        end

        machine
      end
    end

    module InstanceMethods
      private

      def set_state(machine, target, transition, state_attr, save_with_method)
        result = nil
        defused_error = nil

        target.with_lock do
          transition.run_before_callbacks
          result = execute_transition(target, transition, state_attr, save_with_method)
          transition.run_after_callbacks

          result
        rescue StandardError => error
          if machine.defuse_registry.resolve(transition).find { |error_class| error.is_a?(error_class) }
            defused_error = error
          else
            raise error
          end
        end

        raise defused_error if defused_error

        transition.run_success_callbacks || result
      rescue StandardError => error
        target.assign_attributes(state_attr => transition.from.to_s)

        raise unless save_with_method == :save && error.is_a?(NxtStateMachine::Errors::TransitionHalted)

        false
      end

      def execute_transition(target, transition, state_attr, save_with_method)
        transition.execute do |block|
          result = block ? block.call : nil
          target.assign_attributes(state_attr => transition.to.to_s)
          set_state_result = target.send(save_with_method) || halt_transition
          block ? result : set_state_result
        end
      end
    end

    def self.included(base)
      base.include(NxtStateMachine)
      base.include(InstanceMethods)
      base.extend(ClassMethods)
    end
  end
end
