RSpec.describe NxtStateMachine do

  let(:application) do
    Class.new do
      include NxtStateMachine

      def initialize
        @state = :draft
      end

      attr_accessor :state

      state_machine do
        transition_with do |from, to|
          self.state = to
        end

        state :draft
        state :approved
        state :rejected

        event :approve, from: :draft, to: :approved do
          puts 'approved'
        end
      end
    end
  end

  subject do
    application.new
  end

  describe '.state' do
    it 'adds a state to the state machine' do
      expect { subject.approve }.to change { subject.state }.from(:draft).to(:approved)
    end
  end
end
