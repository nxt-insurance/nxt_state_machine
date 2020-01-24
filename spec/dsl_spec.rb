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
              set_state_with do |transition, context|
                transition.execute do |block|
                  block.call
                  self.state = transition.to
                end
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

        describe '#names' do
          it do
            expect(subject.state_machine.events.values.flat_map(&:names)).to eq([:approve, :approve!])
          end
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
            state :rejected, index: 3
            state :published, pre_published: false, index: 2 do
              def category
                'crazy'
              end
            end
          end
        end
      end

      it 'is possible to pass options to a state' do
        expect(subject.state_machine.states.resolve(:draft).options[:pre_published]).to be_truthy
        expect(subject.state_machine.states.resolve(:approved).options['pre_published']).to be_truthy
        expect(subject.state_machine.states.resolve(:published).options[:pre_published]).to be_falsey
      end

      it 'is possible to add methods to states' do
        state = subject.state_machine.states.fetch('published')
        expect(state.category).to eq('crazy')
      end

      it 'is possible to navigate between states' do
        expect(subject.state_machine.states.resolve(:draft).next.enum).to eq(:approved)
        expect(subject.state_machine.states.resolve(:draft).first?).to be_truthy
        expect(subject.state_machine.states.resolve(:draft).last?).to be_falsey

        expect(subject.state_machine.states.resolve(:approved).next.enum).to eq(:published)
        expect(subject.state_machine.states.resolve(:approved).first?).to be_falsey
        expect(subject.state_machine.states.resolve(:approved).last?).to be_falsey

        expect(subject.state_machine.states.resolve(:published).next.enum).to eq(:rejected)
        expect(subject.state_machine.states.resolve(:published).last?).to be_falsey
        expect(subject.state_machine.states.resolve(:published).first?).to be_falsey

        expect(subject.state_machine.states.resolve(:rejected).next.enum).to eq(:draft)
        expect(subject.state_machine.states.resolve(:rejected).last?).to be_truthy
        expect(subject.state_machine.states.resolve(:rejected).first?).to be_falsey
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
                         "A state with the name 'draft' was already registered!"
      end
    end

    context 'events' do
      subject do
        Class.new do
          include NxtStateMachine

          state_machine do
            state :draft
            state :finalized
            state :approved
            state :rejected

            event :finalize do
              transition from: :draft, to: :finalized
            end

            event :approve do
              transition from: :finalized, to: :approved
            end

            event :reject do
              transition from: [:finalized, :approved], to: :rejected
            end
          end
        end
      end

      it 'is possible to access events on the states' do
        expect(subject.state_machine.states.resolve(:draft).events.map(&:name)).to eq([:finalize])
        expect(subject.state_machine.states.resolve(:finalized).events.map(&:name)).to eq([:approve, :reject])
        expect(subject.state_machine.states.resolve(:approved).events.map(&:name)).to eq([:reject])
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

  context 'transitions' do
    subject do
      Class.new do
        include NxtStateMachine

        state_machine do
          state :draft, :finalized, :approved

          event :approve do
            transition from: :draft, to: :approved
            transition from: :finalized, to: :approved
          end

          event :finalize do
            transition from: :approved, to: :finalized
            transition from: :finalized, to: :finalized
          end
        end
      end
    end

    describe '#transitions' do
      it 'returns all transitions' do
        expect(subject.state_machine.transitions.count).to eq(4)

        expect(
          subject.state_machine.transitions.map { |t| "#{t.from.enum} => #{t.to.enum}"}
        ).to match_array(
      ["approved => finalized", "draft => approved", "finalized => approved", "finalized => finalized"]
        )
      end
    end

    describe '#all_transitions_from_to' do
      it 'returns all matching transitions' do
        expect(
          subject.state_machine.all_transitions_from_to(from: :finalized).map { |t| "#{t.from.enum} => #{t.to.enum}"}
        ).to match_array(["finalized => approved", "finalized => finalized"])

        expect(
          subject.state_machine.all_transitions_from_to(from: :approved).map { |t| "#{t.from.enum} => #{t.to.enum}"}
        ).to match_array(["approved => finalized"])

        expect(
          subject.state_machine.all_transitions_from_to(from: :draft).map { |t| "#{t.from.enum} => #{t.to.enum}"}
        ).to match_array(["draft => approved"])
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

          set_state_with do |target, transition|
            transition.execute do |block|
              block.call
              self.state = transition.to.enum
            end
          end

          state :draft, initial: true
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
