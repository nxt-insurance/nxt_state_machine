module NxtStateMachine
  class Registry < ActiveSupport::HashWithIndifferentAccess
    def initialize(name, on_key_occupied: default_duplicate_key_error, on_key_missing: nil)
      @name = name
      @on_key_occupied = on_key_occupied
      @on_key_missing = on_key_missing
      super()
    end

    def []=(key, value)
      on_key_occupied.call(key) if key?(key)

      super
    end

    def [](key)
      if on_key_missing && !has_key?(key)
        on_key_missing.call(self, key)
      end

      super
    end

    private

    attr_reader :name, :on_key_occupied, :on_key_missing

    def default_duplicate_key_error
      -> (key) { raise KeyError, "Key #{key} already taken in registry: #{name}" }
    end
  end
end
