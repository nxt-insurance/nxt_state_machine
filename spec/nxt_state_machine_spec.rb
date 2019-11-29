RSpec.describe NxtStateMachine do

  let(:article) { Article.new(type: 'manual_approval') }

  subject do
    ArticleWorkflow.new(article)
  end

  describe '.transition' do
    it do
      binding.pry
    end
  end
end
