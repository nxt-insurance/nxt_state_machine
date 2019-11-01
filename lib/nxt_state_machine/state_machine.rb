module NxtStateMachine
  class StateMachine
    def initialize(context)
      @context = context
      @states = {}
      @transitions = {}
      @current_state = nil
    end

    attr_accessor :context, :states, :transitions, :current_state

    def configure(&block)
      instance_exec(&block)
    end

    def state(name, initial: false)
      # should probably add_state
      state = State.new(name, initial: initial)
      states[name] = state
      self.current_state = state if initial
      state
    end

    def event(name, from:, to:, &block)
      # should probably add_transition
      transition = Transition.new(name, from: from, to: to, &block)
      transitions[name] = transition

      Array(from).each do |from|
        states[from].transitions << to
      end

      # we might also put this in a module for easy overwriting
      context.define_method name do |*args, **opts|
        # we might want to pass in the current_state here
        transition.execute(self, *args, **opts)
      end
    end
  end
end
