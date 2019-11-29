RSpec.describe NxtStateMachine do

  let(:article) { Article.new(type: 'manual_approval') }
  let(:headline) { 'Article about state machines' }

  subject do
    ArticleWorkflow.new(article)
  end

  describe '#<event>' do
    context 'when the transition exists' do
      it do
        expect { subject.write }.to change { article.status }.from(nil).to('written')
        expect { subject.write }.to_not change { article.reload.status }
        expect { subject.submit }.to change { article.reload.status }.from('written').to('submitted')

        expect(subject.approve(headline: headline)).to be_truthy
        expect(article.reload.status).to eq('approved')
        expect(article.headline).to eq(headline)
      end
    end

    context 'when the transition does not exist' do
      it 'raises an error' do
        binding.pry
        expect { subject.submit }.to raise_error NxtStateMachine::Errors::TransitionNotDefined
      end
    end
  end

  describe '#can_<event>?' do

  end
end
