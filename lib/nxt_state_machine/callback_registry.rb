module NxtStateMachine
  # TODO: This is also shit since it does not complain about misspelled keys
  class CallbackRegistry < Registry
    def initialize
      super(
        "callbacks",
        on_key_missing: Proc.new do |callbacks, from|
          callbacks[from] = Registry.new(
            "#{name}_callbacks_#{from}",
            on_key_missing: Proc.new do |from_registry, to|
              from_registry[to] = Registry.new(
                "#{name}_callbacks_#{from}_#{to}",
                on_key_missing: Proc.new do |to_registry, callback_kind|
                  to_registry[callback_kind] = []
                end
              )
            end
          )
        end
      )
    end

    def register(from, to, kind, method = nil, block = nil)
      method_or_block = method || block
      return unless method_or_block

      Array(from).each do |from_state|
        Array(to).each do |to_state|
          self[from_state][to_state][kind] << method_or_block
        end
      end
    end

    def resolve(transition, kind = nil)
      @resolve ||= ActiveSupport::HashWithIndifferentAccess.new

      all_callbacks = @resolve[transition.id] ||= self[transition.from][transition.to]
      return all_callbacks unless kind

      # We should check if kind is in [:before, :after, :around]

      all_callbacks[kind]
    end
  end
end
