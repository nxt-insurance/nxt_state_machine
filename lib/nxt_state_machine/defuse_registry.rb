module NxtStateMachine
  class DefuseRegistry
    include ::NxtRegistry

    def register(from, to, kind)
      Array(from).each do |from_state|
        Array(to).each do |to_state|
          defusing_errors = errors.from(from_state).to(to_state)
          Array(kind).each_with_object(defusing_errors) { |error, acc| acc << error }
        end
      end
    end

    def resolve!(transition)
      errors.from!(transition.from.enum).to!(transition.to.enum)
    end

    private

    def errors
      @errors ||= registry :from do
        level :to, default: -> { [] }
      end
    end
  end
end
