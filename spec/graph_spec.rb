RSpec.describe NxtStateMachine::Graph do

  let(:article) { Article.new(type: 'manual_approval') }

  let(:state_machine) { ArticleWorkflow.new(article, test: 'options') }

  subject do
    described_class.new(ArticleWorkflow.state_machine).draw
  end

  describe '#draw' do
    it 'draws a graph' do
      expect(subject).to be_truthy
    end
  end
end
