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
        end

        def set_state(transition, context)
          transition.call
          self.state = transition.to
        end

        def skip_callbacks_and_set_state(transition, context, callbacks)
          # we accept callbacks so that they are nor handled before
          # then we do nothing with them, thus they are skipped
          transition.call
          self.state = transition.to
        end

        def run_callbacks_and_set_state(transition, context, callbacks)
          callbacks[:before].each { |c| context.instance_exec(&c) }
          transition.call
          result = self.state = transition.to
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
          }.from(be_empty).to(
            ["before transition", "around enter 1", "around enter 2", "during transition", "around exit 2", "around exit 1", "after transition"]
          )
        end
      end

      context '<event>!' do
        it 'executes the callbacks in the correct order' do
          expect {
            subject.process!
          }.to change {
            subject.result
          }.from(be_empty).to(
            ["before transition", "around enter 1", "around enter 2", "during transition", "around exit 2", "around exit 1", "after transition"]
          )
        end
      end
    end

    context 'when caller expects callbacks to be passed' do
      let(:set_state_with) { :skip_callbacks_and_set_state }
      let(:set_state_with_bang) { :run_callbacks_and_set_state }

      before do
        # reset the set_state methods
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
