RSpec.describe NxtStateMachine::AttrAccessor do
  let(:state_machine_class) do
    Class.new do
      include NxtStateMachine::Hash

      def initialize(status: nil)
        @state_holder = {}
        @state_holder[:status] = status if status
      end

      attr_reader :state_holder
      attr_accessor :processed_at, :accepted_at

      state_machine(target: :state_holder, state_attr: :status) do
        state :received, initial: true
        state :processed, :accepted

        event :process do
          transitions from: :received, to: :processed do |processed_at:|
            self.processed_at = processed_at
          end
        end

        event :accept do
          transitions from: :processed, to: :accepted do |accepted_at:|
            self.accepted_at = accepted_at
            raise ZeroDivisionError, 'oh oh'
          end
        end
      end

      def status
        state_holder[:status]
      end
    end
  end

  describe '.new' do
    context 'when the state was not yet set' do
      subject do
        state_machine_class.new
      end

      it 'sets the initial state' do
        expect(subject.status).to eq(:received)
      end
    end

    context 'when the state was already set' do
      subject do
        state_machine_class.new(status: 'processed')
      end

      it 'does not change the state' do
        expect(subject.status).to eq('processed')
      end
    end

    context 'when no initial state was set' do
      let(:state_machine_class) do
        Class.new do
          include NxtStateMachine::AttrAccessor

          def initialize(status: nil)
            @status = status
          end

          attr_accessor :status

          state_machine(state_attr: :status) do
            state :received, :processed, :accepted, :rejected
          end
        end
      end

      subject do
        state_machine_class.new
      end

      it 'does not set an initial state' do
        expect(subject.status).to be_nil
      end
    end
  end

  describe '#<event>' do
    context 'when there is no error' do
      subject do
        state_machine_class.new
      end

      it 'executes the transition' do
        expect { subject.process(processed_at: 'now') }.to change { subject.status }.from(:received).to(:processed)
        expect(subject.processed_at).to eq('now')
      end
    end

    context 'when there is an error' do
      subject do
        state_machine_class.new(status: 'processed')
      end

      it 'does not set the state' do
        expect { subject.accept(accepted_at: 'now') }.to raise_error(ZeroDivisionError)
        expect(subject.accepted_at).to eq('now')
        expect(subject.status).to eq(:processed)
      end
    end
  end

  describe '#<event>!' do
    context 'when there is no error' do
      subject do
        state_machine_class.new
      end

      it 'executes the transition' do
        expect { subject.process!(processed_at: 'now') }.to change { subject.status }.from(:received).to(:processed)
        expect(subject.processed_at).to eq('now')
      end
    end

    context 'when there is an error' do
      subject do
        state_machine_class.new(status: 'processed')
      end

      it 'does not set the state' do
        expect { subject.accept!(accepted_at: 'now') }.to raise_error(ZeroDivisionError)
        expect(subject.accepted_at).to eq('now')
        expect(subject.status).to eq(:processed)
      end
    end
  end
end
