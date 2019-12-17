RSpec.describe NxtStateMachine do

  let(:article) { Article.new(type: 'manual_approval') }
  let(:headline) { 'Article about state machines' }

  subject do
    ArticleWorkflow.new(article, test: 'options')
  end

  describe '.new' do
    it 'sets the initial state' do
      expect(subject.article.status).to eq('draft')
      expect(subject).to be_draft
    end
  end

  describe '#get_state_with' do
    context 'when the method was not defined' do
      around do |example|
        before = subject.state_machine.get_state_with
        subject.state_machine.instance_variable_set(:@get_state_with, nil)
        example.call
        subject.state_machine.instance_variable_set(:@get_state_with, before)
      end

      it do
        expect {
          subject.current_state_name
        }.to raise_error NxtStateMachine::Errors::MissingConfiguration, /Configuration method :get_state_with was not defined/
      end
    end
  end

  describe '#set_state_with' do
    context 'when the method was not defined' do
      around do |example|
        before = subject.state_machine.set_state_with
        subject.state_machine.instance_variable_set(:@set_state_with, nil)
        example.call
        subject.state_machine.instance_variable_set(:@set_state_with, before)
      end

      it do
        expect {
          subject.write
        }.to raise_error NxtStateMachine::Errors::MissingConfiguration, /Configuration method :set_state_with was not defined/
      end
    end
  end

  describe '#set_state_with!' do
    context 'when the method was not defined' do
      around do |example|
        before = subject.state_machine.set_state_with!
        subject.state_machine.instance_variable_set(:@set_state_with_bang, nil)
        example.call
        subject.state_machine.instance_variable_set(:@set_state_with_bang, before)
      end

      it do
        expect {
          subject.write!
        }.to raise_error NxtStateMachine::Errors::MissingConfiguration, /Configuration method :set_state_with! was not defined/
      end
    end
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
        expect { subject.submit }.to raise_error NxtStateMachine::Errors::TransitionNotDefined
      end

      it 'does not change the state' do
        expect { subject.write }.to change { article.status }.to('written')
        expect { subject.publish }.to raise_error NxtStateMachine::Errors::TransitionNotDefined
        expect(article.reload.status).to eq('written')
      end
    end
  end

  describe '#<event>!' do
    context 'and the transition exists' do
      it 'transitions with the :set_state_with! method ' do
        expect { subject.write! }.to change { article.status }.from(nil).to('written')
        expect { subject.write! }.to_not change { article.reload.status }
        expect { subject.submit! }.to change { article.reload.status }.from('written').to('submitted')
        expect { subject.approve!(headline: nil) }.to raise_error ActiveRecord::RecordInvalid
      end
    end

    context 'but the transition does not exist' do
      it do
        expect { subject.submit! }.to raise_error NxtStateMachine::Errors::TransitionNotDefined
      end
    end
  end

  describe '#can_<event>?' do
    context 'when the transition is possible' do
      it do
        expect(subject.can_write?).to be_truthy
        expect(subject.can_reject?).to be_truthy
        expect(subject.can_delete?).to be_truthy
      end
    end

    context 'when the transition is not possible' do
      it do
        expect(subject.can_submit?).to be_falsey
        expect(subject.can_approve?).to be_falsey
        expect(subject.can_publish?).to be_falsey
      end
    end
  end

  describe 'callbacks' do

  end
end
