RSpec.describe NxtStateMachine do
  context 'when used with a simple state attribute' do
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
            before_transition from: any_state do
              append_result 'before transition'
            end

            transitions from: :received, to: :processed do
              append_result 'during transition'
            end

            after_transition from: any_state do
              append_result 'after transition'
            end
          end
        end

        def set_state(context, from, to, transition)
          transition.call
          self.state = to
        end

        def skip_callbacks_and_set_state(context, from, to, transition, callbacks)
          transition.call
          self.state = to
        end

        def run_callbacks_and_set_state(context, from, to, transition, callbacks)
          callbacks[:before].each { |c| context.instance_exec(&c) }
          transition.call
          result = self.state = to
          callbacks[:after].each { |c| context.instance_exec(&c) }
          result
        end

        def append_result(tmp)
          result << tmp
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
            subject.result
          }.from(be_empty).to(["before transition", "during transition", "after transition"])
        end
      end

      context '<event>!' do
        it 'executes the callbacks in the correct order' do
          expect {
            subject.process!
          }.to change {
            subject.result
          }.from(be_empty).to(["before transition", "during transition", "after transition"])
        end
      end
    end

    context 'when caller expects callbacks to be passed' do
      let(:set_state_with) { :skip_callbacks_and_set_state }
      let(:set_state_with_bang) { :run_callbacks_and_set_state }

      before do
        subject.state_machine.instance_variable_set(:@set_state_with, nil)
        subject.state_machine.set_state_with(set_state_with)

        subject.state_machine.instance_variable_set(:@set_state_with_bang, nil)
        subject.state_machine.set_state_with!(set_state_with_bang)
      end

      context '<event>' do
        it 'leaves it up  to the caller to execute callbacks' do
          expect {
            subject.process
          }.to change {
            subject.result
          }.from(be_empty).to(["during transition"])
        end
      end

      context '<event>!' do
        it 'leaves it up  to the caller to execute callbacks' do
          expect {
            subject.process!
          }.to change {
            subject.result
          }.from(be_empty).to(["before transition", "during transition", "after transition"])
        end
      end
    end
  end
end
