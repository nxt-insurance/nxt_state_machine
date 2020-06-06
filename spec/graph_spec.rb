RSpec.describe NxtStateMachine::Graph do
  subject do
    described_class.new(ArticleWorkflow.state_machine).draw
  end

  describe '#draw' do
    it 'draws a graph' do
      expect(subject).to be_truthy
    end
  end
end
