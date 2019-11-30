require 'active_support/all'
require "nxt_state_machine/version"
require "nxt_state_machine/errors"
require "nxt_state_machine/registry"
require "nxt_state_machine/transitions_store"
require "nxt_state_machine/state"
require "nxt_state_machine/event"
require "nxt_state_machine/callback"
require "nxt_state_machine/transition"
require "nxt_state_machine/state_machine"
require "nxt_state_machine/active_record"

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

      instance.current_state_name
      instance
    end
  end

  module InstanceMethods
    def state_machine
      @state_machine ||= self.class.state_machine
    end

    def current_state_name
      instance_exec(&state_machine.get_state_with)
    end

    def current_state
      state_machine.states.fetch(current_state_name)
    end

    delegate :initial_state, :states, to: :state_machine
  end

  def self.included(base)
    base.extend(ClassMethods)
    base.include(InstanceMethods)
  end
end
