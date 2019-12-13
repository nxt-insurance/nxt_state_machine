RSpec.describe NxtStateMachine do
  let(:state_machine_class) do
    Class.new do
      include NxtStateMachine::ActiveRecord

      def initialize
        @workflow = Workflow.new
        @error_workflow = ErrorWorkflow.new
      end

      attr_accessor :workflow, :error_workflow

      state_machine(scope: :workflow, state: :status) do
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

      state_machine(:error, scope: :error_workflow, state: :status) do
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
