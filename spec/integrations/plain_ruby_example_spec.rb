RSpec.describe NxtStateMachine do
  context 'custom integration' do
    let(:state_machine_class) do
      Class.new do
        include NxtStateMachine

        def initialize(state)
          @state = state
          @result = []
        end

        attr_accessor :state, :result

        state_machine do
          get_state_with :state
          set_state_with :set_state
          set_state_with! :set_state

          state :received, initial: true
          state :processed, :accepted, :rejected

          event :process do
            before_transition from: any_state, to: :processed do
              append_result 'before transition'
            end

            transitions from: :received, to: :processed do
              append_result 'during transition'
            end

            around_transition from: :received, to: :processed do |block|
              append_result 'around enter 1'
              block.call
              append_result 'around exit 1'
            end

            after_transition from: any_state, to: :processed do
              append_result 'after transition'
            end
          end

          # We can also define callbacks directly within the state machine
          around_transition from: any_state, to: all_states do |block|
            append_result 'around enter 2'
            block.call
            append_result 'around exit 2'
          end

          around_transition from: any_state, to: all_states, run: :say_hello
        end

        def set_state(transition)
          transition.run_before_callbacks

          result = transition.execute do
            transition.apply_block
            self.state = transition.to.enum
          end

          result && transition.run_after_callbacks && result
        end

        def append_result(tmp)
          result << tmp
        end

        def say_hello(block)
          append_result('hello')
          block.call
          append_result('good bye')
        end
      end
    end

    subject do
      state_machine_class.new('received')
    end

    context '<event>' do
      context '#set_state' do
        context 'when there is no error' do
          it 'sets the state' do
            expect(subject.process).to be_truthy
            expect(subject.state).to eq(:processed)
          end
        end
      end

      context 'callbacks' do
        it 'executes the callbacks in the correct order' do
          expect {
            subject.process
          }.to change {
            subject.result
          }.from(be_empty).to(
            [
              "before transition",
              "around enter 1",
              "around enter 2",
              "hello",
              "during transition",
              "good bye",
              "around exit 2",
              "around exit 1",
              "after transition"
            ]
          )
        end
      end
    end

    context '<event>!' do
      context 'when there is no error' do
        it 'sets the state' do
          expect(subject.process!).to be_truthy
          expect(subject.state).to eq(:processed)
        end
      end

      context 'callbacks' do
        it 'executes the callbacks in the correct order' do
          expect {
            subject.process!
          }.to change {
            subject.result
          }.from(be_empty).to(
            [
              "before transition",
              "around enter 1",
              "around enter 2",
              "hello",
              "during transition",
              "good bye",
              "around exit 2",
              "around exit 1",
              "after transition"
            ]
          )
      end
    end
  end
  end
end
