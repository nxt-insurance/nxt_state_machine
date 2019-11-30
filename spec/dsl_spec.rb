RSpec.describe NxtStateMachine do
  let(:workflow) do
    Class.new do
      include NxtStateMachine
    end
  end

  describe '.event' do
    context 'when the event was not registered before' do
      context 'and the event has transitions' do
        subject do
          workflow.class_eval do
            def initialize
              @state = nil
            end

            attr_accessor :state

            state_machine do
              get_state_with { self.state ||= :draft }
              set_state_with do |from, to, transition|
                transition.call
                self.state = to
              end

              state :draft, initial: true
              state :approved

              event :approve do
                transition from: :draft, to: :approved
              end
            end
          end

          workflow.new
        end

        it 'adds the :approve method' do
          expect(subject.respond_to?(:approve)).to be_truthy
        end

        it 'adds the :can_approve? method' do
          expect(subject.respond_to?(:can_approve?)).to be_truthy
          expect(subject.can_approve?).to be_truthy
        end
      end

      context 'but there were no transitions defined for the event' do
        subject do
          workflow.state_machine do
            state :draft
            state :approved

            event :approve do

            end
          end
        end

        it do
          expect {
            subject
          }.to raise_error NxtStateMachine::Errors::EventWithoutTransitions,
                           "No transitions for event :approve defined"
        end
      end
    end

    context 'when the event was registered before' do
      subject do
        Class.new do
          include NxtStateMachine

          state_machine do
            state :draft
            state :finalized
            state :approved

            event :finalize do
              transition from: :draft, to: :finalized
            end

            event :finalize do
              transition from: :finalized, to: :approved
            end
          end
        end
      end

      it do
        expect {
          subject
        }.to raise_error NxtStateMachine::Errors::EventAlreadyRegistered,
                         "An event with the name 'finalize' was already registered!"
      end
    end
  end

  describe '.state' do
    context 'options' do
      subject do
        Class.new do
          include NxtStateMachine

          state_machine do
            state :draft, pre_published: true
            state :approved, pre_published: true
            state :published, pre_published: false
          end
        end
      end

      it 'is possible to pass options to a state' do
        expect(subject.state_machine.states.fetch(:draft).options[:pre_published]).to be_truthy
        expect(subject.state_machine.states.fetch(:approved).options['pre_published']).to be_truthy
        expect(subject.state_machine.states.fetch(:published).options[:pre_published]).to be_falsey
      end
    end

    context 'when a state with the same name was registered before' do
      subject do
        Class.new do
          include NxtStateMachine

          state_machine do
            state :draft
            state :draft
            state :approved
          end
        end
      end

      it do
        expect {
          subject
        }.to raise_error NxtStateMachine::Errors::StateAlreadyRegistered,
                         "An state with the name 'draft' was already registered!"
      end
    end
  end

  describe '.transition' do
    context 'when the transition already was registered before' do
      subject do
        Class.new do
          include NxtStateMachine

          state_machine do
            state :draft
            state :finalized
            state :approved

            event :finalize do
              transition from: :draft, to: :finalized
            end

            event :approve do
              transition from: :draft, to: :finalized
            end
          end
        end
      end

      it do
        expect {
          subject
        }.to raise_error NxtStateMachine::Errors::TransitionAlreadyRegistered,
                         "A transition from :draft to :finalized was already registered"
      end
    end
  end

  describe '.set_state_with' do
    subject do
      workflow.class_eval do
        def initialize
          @state = nil
          @approved_at = nil
        end

        attr_accessor :state, :approved_at

        state_machine do
          get_state_with { self.state ||= :draft }

          set_state_with do |from, to, transition|
            transition.call
            self.state = to
          end

          state :draft
          state :approved

          event :approve do
            transition from: :draft, to: :approved do |approved_at:|
              self.approved_at = approved_at
            end
          end
        end
      end

      workflow.new
    end

    it do
      now = Time.current

      expect {
        subject.approve(approved_at: now)
      }.to change { subject.state }.from(:draft).to(:approved)

      expect(subject.approved_at).to eq(now)
    end
  end
end
