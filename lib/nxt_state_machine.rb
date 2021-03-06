require 'active_support/all'
require 'nxt_registry'
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
require "nxt_state_machine/callable"
require "nxt_state_machine/state_registry"
require "nxt_state_machine/callback_registry"
require "nxt_state_machine/error_callback_registry"
require "nxt_state_machine/defuse_registry"
require "nxt_state_machine/event_registry"
require "nxt_state_machine/state"
require "nxt_state_machine/event"
require "nxt_state_machine/event/names"
require "nxt_state_machine/transition/interface"
require "nxt_state_machine/transition"
require "nxt_state_machine/transition/factory"
require "nxt_state_machine/transition/proxy"
require "nxt_state_machine/transition/around_callback_chain"
require "nxt_state_machine/state_machine"
require "nxt_state_machine/integrations/active_record"
require "nxt_state_machine/integrations/attr_accessor"
require "nxt_state_machine/integrations/hash"
require "nxt_state_machine/graph"

module NxtStateMachine
  module ClassMethods
    include NxtRegistry

    def state_machine(name = :default, **opts, &config)
      state_machines.resolve(name) || state_machines.register(
        name,
        StateMachine.new(name, self, state_machine_event_registry, **opts).configure(&config)
      )
    end

    def state_machines
      @state_machines ||= registry :state_machines
    end

    def new(*args, **opts, &block)
      instance = if opts.any?
        super(*args, **opts, &block)
      else
        super(*args, &block)
      end

      # set each initial state for all machines
      state_machines.each do |name, machine|
        instance.current_state_name(name) if machine.initial_state.present?
      end

      instance
    end

    private

    def state_machine_event_registry
      @state_machine_event_registry ||= EventRegistry.new
    end
  end

  module InstanceMethods
    def state_machines
      @state_machines ||= self.class.state_machines
    end

    def state_machine(name = :default)
      @state_machine ||= self.class.state_machines.resolve!(name)
    end

    def current_state_name(name = :default)
      state_machines.resolve!(name).current_state_name(self)
    end

    def current_state(name = :default)
      state_machines.resolve!(name).states.resolve!(current_state_name(name))
    end

    def halt_transition(*args, **opts)
      raise NxtStateMachine::Errors::TransitionHalted.new(*args, **opts)
    end

    delegate :initial_state, :states, to: :state_machine
  end

  def self.included(base)
    base.extend(ClassMethods)
    base.include(InstanceMethods)
  end
end
