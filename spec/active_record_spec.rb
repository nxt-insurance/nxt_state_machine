RSpec.describe NxtStateMachine::ActiveRecord do
  context 'when used directly in a model' do
    subject do
      ApplicationWithStateMachine.active_record_state_machine(state: :status) do
        state :received, initial: true
        state :processed
        state :accepted
        state :rejected

        event :process do
          transition from: :received, to: :processed do |processed_at|
            self.processed_at = processed_at
          end
        end

        event :accept do
          transition from: :processed, to: :accepted do |accepted_at|
            self.accepted_at = accepted_at
          end
        end
      end

      ApplicationWithStateMachine.new(status: 'received')
    end

    context '#<event>' do
      context 'when the record is invalid' do
        it do
          # TODO
        end
      end
    end

    context 'callbacks' do
# TODO
    end
  end

  context 'when used with a separate class' do
    let(:state_machine_class) do
      Class.new do
        include NxtStateMachine::ActiveRecord

        def initialize(application)
          @application = application
        end

        attr_reader :application

        active_record_state_machine(state: :status, scope: :application) do
          state :received, initial: true
          state :processed
          state :accepted
          state :rejected

          event :process do
            transition from: :received, to: :processed do |processed_at|
              application.processed_at = processed_at
            end
          end

          event :accept do
            transition from: :processed, to: :accepted do |accepted_at|
              application.accepted_at = accepted_at
            end
          end
        end
      end
    end

    let(:application) { Application.new }

    subject do
      state_machine_class.new(application)
    end

    context '#<event>' do
      context 'when the record is invalid' do
        it do
          binding.pry
        end
      end
    end

    context 'callbacks' do

    end
  end
end
