module NxtStateMachine
  class CallbackRegistry
    include ::NxtRegistry

    def register(from, to, kind, method = nil, block = nil)
      method_or_block = method || block
      return unless method_or_block

      Array(from).each do |from_state|
        Array(to).each do |to_state|
          callbacks.from!(from_state).to!(to_state).kind!(kind) << method_or_block
        end
      end
    end

    def resolve!(transition, kind = nil)
      all_callbacks = callbacks.from!(transition.from.enum).to!(transition.to.enum)
      return all_callbacks unless kind

      all_callbacks.kind(kind)
    end

    private

    def callbacks
      @callbacks ||= registry :from do
        level :to do
          level :kind, default: -> { [] } do
            attrs :before, :after
          end
        end
      end
    end
  end
end
