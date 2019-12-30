module NxtStateMachine
  class ErrorCallbackRegistry
    include ::NxtRegistry

    def register(from, to, error, method = nil, block = nil)
      method_or_block = method || block
      return unless method_or_block

      Array(from).each do |from_state|
        Array(to).each do |to_state|
          callbacks.from(from_state.to_s).to(to_state.to_s).error(error, method_or_block)
        end
      end
    end

    def resolve(error, transition)
      candidate = callbacks.from(transition.from.to_s).to(transition.to.to_s).error.keys.find { |kind_of_error| error.is_a?(kind_of_error) }
      return unless candidate

      callbacks.from(transition.from.to_s).to(transition.to.to_s).error(candidate)
    end

    private

    def callbacks
      @callbacks ||= registry :from do
        nested :to do
          nested :error
        end
      end
    end
  end
end
