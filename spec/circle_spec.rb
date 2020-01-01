RSpec.describe NxtStateMachine::ActiveRecord do
  context 'when used directly in a model' do
    let(:state_machine_class) do
      Class.new(Workflow) do
        include NxtStateMachine::ActiveRecord

        state_machine(state_attr: :status) do
          state :a, initial: true
          state :b, :c, :d

          event :next do
            before_transition from: any_state, to: all_states do |transition|
              parts = comment.split(' | ')
              parts << "#{transition.from.enum} => #{transition.to.enum}"
              self.comment = parts.join(' | ')
            end

            transitions from: :a, to: :b do |iteration:|
              self.comment += " #{iteration}"
            end

            transitions from: :b, to: :c do |iteration:|
              self.comment += " #{iteration}"
            end

            transitions from: :c, to: :d do |iteration:|
              self.comment += " #{iteration}"
            end

            transitions from: :d, to: :a do |iteration:|
              self.comment += " #{iteration}"
            end
          end
        end
      end
    end

    subject do
      state_machine_class.new(comment: '')
    end

    it 'is possible to transition in circles' do
      4.times { subject.next!(iteration: 1) }
      4.times { subject.next!(iteration: 2) }

      expect(
        subject.reload.comment
      ).to eq("a => b 1 | b => c 1 | c => d 1 | d => a 1 | a => b 2 | b => c 2 | c => d 2 | d => a 2")
    end
  end
end
