module NxtStateMachine
  class CallbackRegistry
    include ::NxtRegistry

    def register(from, to, kind, method = nil, block = nil)
      method_or_block = method || block
      return unless method_or_block

      Array(from).each do |from_state|
        Array(to).each do |to_state|
          callbacks.from(from_state.to_s).to(to_state.to_s).kind(kind.to_s) << method_or_block
        end
      end
    end

    def resolve(transition, kind = nil)
      all_callbacks = callbacks.from(transition.from.to_s).to(transition.to.to_s)
      return all_callbacks unless kind

      all_callbacks.kind(kind.to_s)
    end

    private

    def callbacks
      @callbacks ||= begin
        registry :from do
          nested :to do
            nested :kind, default: -> { [] } do
              attrs :before, :after
            end
          end
        end
      end
    end
  end
end
