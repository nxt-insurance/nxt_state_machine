RSpec.describe NxtStateMachine::ActiveRecord do
  context 'when used directly in a model' do
    let(:state_machine_class) do
      Class.new(Application) do
        include NxtStateMachine::ActiveRecord

        def self.name
          'Application'
        end

        active_record_state_machine(state: :status) do
          state :received, initial: true
          state :processed, :accepted, :rejected

          event :process do
            transitions from: :received, to: :processed do |processed_at|
              self.processed_at = processed_at
            end
          end

          event :accept do
            transitions from: :processed, to: :accepted do |accepted_at|
              self.accepted_at = accepted_at
            end
          end
        end
      end
    end

    describe '.new' do
      context 'when the state was not yet set' do
        subject do
          state_machine_class.new
        end

        it 'sets the initial state' do
          expect(subject.status).to eq('received')
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
    end

    describe '#<event>' do
      context 'when the record is new' do
        context 'when the record is valid' do
          subject do
            state_machine_class.new(content: 'Please make it happen', received_at: Time.current)
          end

          it do
            expect { subject.process(Time.current) }.to change { subject.status }.from('received').to('processed')
          end
        end

        context 'when the record is not valid' do
          subject do
            state_machine_class.new
          end

          it do
            expect { subject.process(Time.current) }.to_not change { subject.status }
            expect { subject.process!(Time.current) }.to raise_error(ActiveRecord::RecordInvalid)
            expect(subject.status).to eq('received')
            expect(subject.new_record?).to be_truthy
          end
        end
      end

      context 'when the record is loaded from the database' do
        context 'and the record is valid' do
          subject do
            state_machine_class.create!(status: 'received', received_at: Time.current, content: 'some content')
          end

          it do
            expect(subject.status).to eq('received')
            expect { subject.process(Time.current) }.to change { subject.reload.status }.from('received').to('processed')
            expect(subject.new_record?).to be_falsey
            expect { subject.accept!(Time.current) }.to change { subject.reload.status }.from('processed').to('accepted')
          end
        end

        context 'but the record is invalid' do
          subject do
            state_machine_class.create!(status: 'received', received_at: Time.current, content: 'some content')
          end

          it do
            subject.received_at = nil
            expect { subject.process(Time.current) }.to_not change { subject.status }
            expect { subject.process!(Time.current) }.to raise_error(ActiveRecord::RecordInvalid)
            expect(subject.reload.status).to eq('received')
          end
        end
      end
    end

    describe 'callbacks' do
      context 'when there is an error' do
        context 'in a before callback' do
          let(:state_machine_class) do
            Class.new(Application) do
              include NxtStateMachine::ActiveRecord

              def self.name
                'Application'
              end

              active_record_state_machine(state: :status) do
                state :received, initial: true
                state :processed, :accepted, :rejected

                event :process do
                  before_transition from: :received do
                    raise ZeroDivisionError, "Error in before_callback"
                  end

                  transition from: :received, to: :processed do |processed_at|
                    self.processed_at = processed_at
                  end
                end
              end
            end
          end

          subject do
            state_machine_class.new
          end

          it 'does not change the state' do
            expect { subject.process(Time.current) }.to raise_error ZeroDivisionError
            expect(subject.status).to eq('received')
            expect(subject.new_record?).to be_truthy

            expect { subject.process!(Time.current) }.to raise_error ZeroDivisionError
            expect(subject.status).to eq('received')
            expect(subject.new_record?).to be_truthy
          end
        end

        context 'during the transition' do
          let(:state_machine_class) do
            Class.new(Application) do
              include NxtStateMachine::ActiveRecord

              def self.name
                'Application'
              end

              active_record_state_machine(state: :status) do
                state :received, initial: true
                state :processed, :accepted, :rejected

                event :process do
                  transition from: :received, to: :processed do |processed_at|
                    self.processed_at = processed_at
                    raise ZeroDivisionError, 'oh oh'
                  end
                end
              end
            end
          end

          subject do
            state_machine_class.new(content: 'some', received_at: Time.current)
          end

          it 'does not change the state' do
            expect { subject.process(Time.current) }.to raise_error ZeroDivisionError
            expect(subject.new_record?).to be_truthy
            expect(subject.status).to eq('received')

            expect { subject.process!(Time.current) }.to raise_error ZeroDivisionError
            expect(subject.new_record?).to be_truthy
            expect(subject.status).to eq('received')
          end
        end

        context 'in an after callback' do
          let(:state_machine_class) do
            Class.new(Application) do
              include NxtStateMachine::ActiveRecord

              def self.name
                'Application'
              end

              active_record_state_machine(state: :status) do
                state :received, initial: true
                state :processed, :accepted, :rejected

                event :process do
                  transition from: :received, to: :processed do |processed_at|
                    self.processed_at = processed_at
                  end

                  after_transition from: :received do
                    raise ZeroDivisionError, "Error in before_callback"
                  end
                end
              end
            end
          end

          subject do
            state_machine_class.new(content: 'some', received_at: Time.current)
          end

          it 'does not change the state' do
            expect { subject.process(Time.current) }.to raise_error ZeroDivisionError
            expect(subject.new_record?).to be_truthy
            expect(subject.status).to eq('received')

            expect { subject.process!(Time.current) }.to raise_error ZeroDivisionError
            expect(subject.new_record?).to be_truthy
            expect(subject.status).to eq('received')
          end
        end
      end
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
          state :processed, :accepted, :rejected

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

    subject do
      state_machine_class.new(application)
    end

    describe '.new' do
      context 'when the state was not yet set' do
        let(:application) { Application.new }

        it 'sets the initial state' do
          expect(subject.application.status).to eq('received')
          expect(subject.application).to be_new_record
        end
      end

      context 'when the state was already set' do
        let(:application) { Application.new(status: 'processed') }

        it 'does not change the state' do
          expect(subject.application.status).to eq('processed')
          expect(subject.application).to be_new_record
        end
      end
    end

    describe '#<event>' do
      context 'when the record is a new record' do
        context 'when the record is valid' do
          let(:application) { Application.new(content: 'Please make it happen', received_at: Time.current) }

          it do
            expect { subject.process(Time.current) }.to change { subject.application.status }.from('received').to('processed')
            expect(subject.application).to be_persisted
          end
        end

        context 'when the record is invalid' do
          let(:application) { Application.new(content: nil, received_at: Time.current) }

          it do
            expect { subject.process(Time.current) }.to_not change { subject.application.status }
            expect(subject.application).to be_new_record

            expect { subject.process!(Time.current) }.to raise_error ActiveRecord::RecordInvalid
            expect(subject.application).to be_new_record
            expect(subject.application.status).to eq('received')
          end
        end
      end

      context 'when the record was loaded from the database' do
        let(:application) { Application.create!(content: 'Please make it happen', received_at: Time.current, status: 'received') }

        context 'when the record is valid' do
          it do
            expect { subject.process(Time.current) }.to change { subject.application.status }.from('received').to('processed')
            expect(subject.application).to be_persisted
            expect { subject.accept!(Time.current) }.to change { subject.application.status }.from('processed').to('accepted')
            expect(subject.application.reload.status).to eq('accepted')
          end
        end

        context 'when the record is invalid' do
          before do
            application.content = nil
          end

          it do
            expect { subject.process(Time.current) }.to_not change { subject.application.status }
            expect { subject.process!(Time.current) }.to raise_error ActiveRecord::RecordInvalid
            expect(subject.application.reload.status).to eq('received')
          end
        end
      end
    end

    context 'callbacks' do
      context 'when there is an error' do
        let(:application) { Application.new(content: 'Please make it happen', received_at: Time.current) }

        context 'in a before callback' do
          let(:state_machine_class) do
            Class.new do
              include NxtStateMachine::ActiveRecord

              def initialize(application)
                @application = application
              end

              attr_reader :application

              active_record_state_machine(state: :status, scope: :application) do
                state :received, initial: true
                state :processed, :accepted, :rejected

                event :process do
                  before_transition from: :received do
                    raise ZeroDivisionError, "Error in before_callback"
                  end

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

          subject do
            state_machine_class.new(application)
          end

          it 'does not change the state' do
            expect { subject.process(Time.current) }.to raise_error ZeroDivisionError
            expect(subject.application).to be_new_record
            expect(subject.application.status).to eq('received')

            expect { subject.process!(Time.current) }.to raise_error ZeroDivisionError
            expect(subject.application).to be_new_record
            expect(subject.application.status).to eq('received')
          end
        end

        context 'during the transition' do
          let(:state_machine_class) do
            Class.new do
              include NxtStateMachine::ActiveRecord

              def initialize(application)
                @application = application
              end

              attr_reader :application

              active_record_state_machine(state: :status, scope: :application) do
                state :received, initial: true
                state :processed, :accepted, :rejected

                event :process do
                  transition from: :received, to: :processed do |processed_at|
                    application.processed_at = processed_at
                    raise ZeroDivisionError, "oh oh"
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

          subject do
            state_machine_class.new(application)
          end

          it 'does not change the state' do
            expect { subject.process(Time.current) }.to raise_error ZeroDivisionError
            expect(subject.application).to be_new_record
            expect(subject.application.status).to eq('received')

            expect { subject.process!(Time.current) }.to raise_error ZeroDivisionError
            expect(subject.application).to be_new_record
            expect(subject.application.status).to eq('received')
          end
        end

        context 'in an after callback' do
          let(:state_machine_class) do
            Class.new do
              include NxtStateMachine::ActiveRecord

              def initialize(application)
                @application = application
              end

              attr_reader :application

              active_record_state_machine(state: :status, scope: :application) do
                state :received, initial: true
                state :processed, :accepted, :rejected

                event :process do
                  transitions from: :received, to: :processed do |processed_at|
                    application.processed_at = processed_at
                  end

                  after_transition from: :received do
                    raise ZeroDivisionError, "oh oh"
                  end
                end

                event :accept do
                  transitions from: :processed, to: :accepted do |accepted_at|
                    application.accepted_at = accepted_at
                  end
                end
              end
            end
          end

          subject do
            state_machine_class.new(application)
          end

          it 'does not change the state' do
            expect { subject.process(Time.current) }.to raise_error ZeroDivisionError
            expect(subject.application).to be_new_record
            expect(subject.application.status).to eq('received')

            expect { subject.process!(Time.current) }.to raise_error ZeroDivisionError
            expect(subject.application).to be_new_record
            expect(subject.application.status).to eq('received')
          end
        end
      end
    end
  end
end
