require 'active_support/all'
require "nxt_state_machine/version"
require "nxt_state_machine/state"
require "nxt_state_machine/transition"
require "nxt_state_machine/state_machine"


module NxtStateMachine
  module ClassMethods
    def state_machine(&block)
      @state_machine ||= StateMachine.new(self)
      @state_machine.configure(&block) if block_given?
      @state_machine
    end
  end

  module InstanceMethods
    def state_machine
      @state_machine ||= self.class.state_machine
    end

    def current_state
      state_machine.current_state
    end
  end

  def self.included(base)
    base.extend(ClassMethods)
    base.include(InstanceMethods)
  end
end
