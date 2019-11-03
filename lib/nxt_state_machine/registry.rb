module NxtStateMachine
  class Registry < ActiveSupport::HashWithIndifferentAccess
    def initialize(name, on_key_error: default_duplicate_key_error)
      @name = name
      @on_key_error = on_key_error
      super()
    end

    def []=(key, value)
      on_key_error.call(key) if key?(key)

      super
    end

    private

    attr_reader :name, :on_key_error

    def default_duplicate_key_error
      -> (key) { raise KeyError, "Key #{key} already taken in registry: #{name}" }
    end
  end
end
