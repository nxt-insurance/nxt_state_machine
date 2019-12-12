require 'active_support/all'
require "nxt_state_machine/version"
require "nxt_state_machine/errors/error"
require "nxt_state_machine/errors/event_already_registered"
require "nxt_state_machine/errors/event_without_transitions"
require "nxt_state_machine/errors/initial_state_already_defined"
require "nxt_state_machine/errors/invalid_callback_option"
require "nxt_state_machine/errors/missing_configuration"
require "nxt_state_machine/errors/state_already_registered"
require "nxt_state_machine/errors/transition_already_registered"
require "nxt_state_machine/errors/transition_not_defined"
require "nxt_state_machine/errors/unknown_state_error"
require "nxt_state_machine/errors/transition_halted"
require "nxt_state_machine/registry"
require "nxt_state_machine/callable"
require "nxt_state_machine/callback_registry"
require "nxt_state_machine/transitions_store"
require "nxt_state_machine/state"
require "nxt_state_machine/event"
require "nxt_state_machine/transition"
require "nxt_state_machine/transition_proxy"
require "nxt_state_machine/state_machine"
require "nxt_state_machine/integrations/active_record"
require "nxt_state_machine/integrations/attr_accessor"

module NxtStateMachine
  module ClassMethods
    def state_machine(**opts, &block)
      @state_machine ||= StateMachine.new(self, opts)
      @state_machine.configure(&block) if block_given?
      @state_machine
    end

    def new(*args, **opts, &block)
      instance = if opts.any?
        super(*args, **opts, &block)
      else
        super(*args, &block)
      end

      instance.current_state_name if state_machine.initial_state.present?
      instance
    end
  end

  module InstanceMethods
    def state_machine
      @state_machine ||= self.class.state_machine
    end

    def current_state_name
      state_machine.get_state_with.with_context(self).call
    end

    def current_state
      state_machine.states.fetch(current_state_name)
    end

    def halt_transition(*args, **opts)
      raise NxtStateMachine::Errors::TransitionHalted.new(*args, **opts)
    end

    def callbacks_for_transition(transition)
      state_machine.callbacks.resolve(transition)
    end

    delegate :initial_state, :states, to: :state_machine
  end

  def self.included(base)
    base.extend(ClassMethods)
    base.include(InstanceMethods)
  end
end
