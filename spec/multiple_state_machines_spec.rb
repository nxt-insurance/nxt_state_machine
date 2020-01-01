RSpec.describe NxtStateMachine do
  context 'when the specifications are valid' do
    let(:state_machine_class) do
      Class.new do
        include NxtStateMachine::ActiveRecord

        def initialize
          @workflow = Workflow.new
          @error_workflow = ErrorWorkflow.new
        end

        attr_accessor :workflow, :error_workflow

        state_machine(target: :workflow, state_attr: :status) do
          state :draft, initial: true
          state :processing, :errored

          event :process do
            transitions from: :draft, to: :processing do |comment:|
              comments = workflow.comment.split(' - ')
              comments << comment
              workflow.comment = comments.join(' - ')
            end
          end

          event :error do
            transitions from: any_state, to: :errored do |comment:|
              start_error_workflow!(comment: comment)

              comments = workflow.comment.split(' - ')
              comments << comment
              workflow.comment = comments.join(' - ')
            end
          end

          event :reset do
            transitions from: :errored, to: :draft
          end
        end

        state_machine(:error, target: :error_workflow, state_attr: :status) do
          state :un_started, initial: true
          state :started, :resolved

          event :start_error_workflow do
            transitions from: :un_started, to: :started do |comment:|
              comments = error_workflow.comment.split(' - ')
              comments << comment
              error_workflow.comment = comments.join(' - ')
            end
          end

          event :resolve_error do
            transitions from: :started, to: :resolved do |comment:|
              comments = error_workflow.comment.split(' - ')
              comments << comment
              error_workflow.comment = comments.join(' - ')
              reset!
            end
          end
        end
      end
    end

    subject do
      state_machine_class.new
    end

    it 'sets the initial states' do
      expect(subject.workflow.status).to eq('draft')
      expect(subject.error_workflow.status).to eq('un_started')
    end

    it do
      subject.process!(comment: 'processing')
      expect(subject.workflow.status).to eq('processing')
      subject.error!(comment: 'error!')
      expect(subject.workflow.status).to eq('errored')
      expect(subject.error_workflow.status).to eq('started')
      subject.resolve_error!(comment: 'error resolved!')
      expect(subject.error_workflow.status).to eq('resolved')
      expect(subject.workflow.status).to eq('draft')
    end
  end

  context 'when the specification is invalid' do
    context 'when the events are not unique across machines' do
      let(:state_machine_class) do
        Class.new do
          include NxtStateMachine::ActiveRecord

          def initialize
            @workflow = Workflow.new
            @error_workflow = ErrorWorkflow.new
          end

          attr_accessor :workflow, :error_workflow

          state_machine(target: :workflow, state_attr: :status) do
            state :draft, initial: true
            state :processing

            event :process do
              transitions from: :draft, to: :processing do |comment:|
                self.comment = comment
              end
            end
          end

          state_machine(:error, target: :error_workflow, state_attr: :status) do
            state :draft, initial: true
            state :processing

            event :process do
              transitions from: :draft, to: :processing do |comment:|
                self.comment = comment
              end
            end
          end
        end
      end

      subject do
        state_machine_class
      end

      it 'raises an error' do
        expect { subject }.to raise_error NxtStateMachine::Errors::EventAlreadyRegistered,
                                          "An event with the name 'process' was already registered!"
      end
    end
  end
end
