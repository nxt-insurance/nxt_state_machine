RSpec.describe NxtStateMachine do
  context 'when used with a simple state attribute' do
    let(:state_machine_class) do
      Class.new do
        include NxtStateMachine

        def initialize(state)
          @state = state
          @string = []
        end

        attr_accessor :state, :string

        state_machine do
          get_state_with :state
          set_state_with :set_state
          set_state_with! :set_state

          state :received, initial: true
          state :processed, :accepted, :rejected

          event :process do
            before_transition from: any_state do
              acc_string 'before transition'
            end

            transitions from: :received, to: :processed do
              acc_string 'during transition'
            end

            after_transition from: any_state do
              acc_string 'after transition'
            end
          end
        end

        def set_state(from, to, transition)
          transition.call
          self.state = to
        end

        def acc_string(substring)
          string << substring
        end
      end
    end

    subject do
      state_machine_class.new('received')
    end

    context 'with default callbacks' do
      context '<event>' do
        it 'executes the callbacks in the correct order' do
          expect {
            subject.process
          }.to change {
            subject.string
          }.from(be_empty).to(["before transition", "during transition", "after transition"])
        end
      end

      context '<event>!' do
        it 'executes the callbacks in the correct order' do
          expect {
            subject.process!
          }.to change {
            subject.string
          }.from(be_empty).to(["before transition", "during transition", "after transition"])
        end
      end
    end
  end
end
