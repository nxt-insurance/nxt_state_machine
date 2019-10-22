require 'active_support/all'
require "nxt_state_machine/version"
require_relative 'nxt_state_machine/state'
require_relative 'nxt_state_machine/event'
require_relative 'nxt_state_machine/transition'
require_relative 'nxt_state_machine/state_machine'

module NxtStateMachine
  module InstanceMethods
  end

  module ClassMethods
    def state(name, &block)
      states[name] = State.new(name, &block)
    end

    def states
      @states ||= {}
    end

    def state_machine(&block)
      instance_exec(&block)
    end

    def before_transition(from:, to:, &block)
      from = before_transition_callbacks[from] ||= {}
      raise KeyError, "Callback already registered for #{from} --> #{to}" if from[to]

      from[to] = block
    end

    def after_transition(from:, to:, &block)
      from = after_transition_callbacks[from] ||= {}
      raise KeyError, "Callback already registered for #{from} --> #{to}" if from[to]

      from[to] = block
    end

    def around_transition(from:, to:, &block)
      from = around_transition_callbacks[from] ||= {}
      raise KeyError, "Callback already registered for #{from} --> #{to}" if from[to]

      from[to] = block
    end

    def event(name, from:, to:, &block)
      events[name] = Event.new(name, from: from, to: to, &block)

      InstanceMethods.module_eval do
        define_method name do
          event = self.class.events[name]
          self.class.events[name].execute(self)
          transition(from: event.from, to: event.to)
          # TODO: Should return false if it cannot transition
        end

        def transition(from:, to:)
          instance_exec(from, to, &self.class.transition_with)
        end
      end
    end

    def events
      @events ||= {}
    end

    def transition_with(&block)
      @transition_with ||= block
    end

    def before_transition_callbacks
      @before_transition_callbacks ||= {}
    end

    def after_transition_callbacks
      @after_transition_callbacks ||= {}
    end

    def around_transition_callbacks
      @around_transition_callbacks ||= {}
    end
  end

  def self.included(base)
    base.extend(ClassMethods)
    base.include(InstanceMethods)
  end
end
