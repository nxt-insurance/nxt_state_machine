RSpec.describe NxtStateMachine::State do
  describe '<=>' do
    subject do
      Class.new do
        include NxtStateMachine

        state_machine do
          state :draft
          state :finalized
          state :approved
          state :rejected
        end
      end
    end

    it 'is possible to compare states by their index' do
      expect(subject.state_machine.states.resolve(:draft)).to be < subject.state_machine.states.resolve(:finalized)
      expect(subject.state_machine.states.resolve(:finalized)).to be < subject.state_machine.states.resolve(:approved)
      expect(subject.state_machine.states.resolve(:approved)).to be < subject.state_machine.states.resolve(:rejected)
      expect(subject.state_machine.states.resolve(:rejected)).to be <= subject.state_machine.states.resolve(:rejected)
      expect(subject.state_machine.states.resolve(:rejected)).to be >= subject.state_machine.states.resolve(:rejected)
      expect(subject.state_machine.states.resolve(:rejected)).to be == subject.state_machine.states.resolve(:rejected)
    end
  end
end
