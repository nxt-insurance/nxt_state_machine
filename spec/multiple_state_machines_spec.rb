RSpec.describe NxtStateMachine do
  let(:state_machine_class) do
    Class.new do
      include NxtStateMachine::ActiveRecord

      def initialize
        @workflow = Workflow.create!(status: :draft)
        @error_workflow = nil # ErrorWorkflow.create!(status: :un_started)
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
          transitions from: :errored, to: :draft do |comment:|
            resolve_error(comment: comment)
          end
        end
      end

      state_machine(:error, scope: :error_workflow, state: :status) do
        state :un_started, initial: true
        state :started, :resolved

        event :start_error_workflow do
          transitions from: :un_started, to: :started do |comment:|
            self.error_workflow = ErrorWorkflow.new

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
          end
        end
      end
    end
  end

  subject do
    state_machine_class.new
  end

  it do
    subject.process!(comment: 'processing')
    expect(subject.workflow.status).to eq('processing')

    binding.pry

    subject.error!(comment: 'error!')
    expect(subject.workflow.status).to eq('errored')
  end
end
