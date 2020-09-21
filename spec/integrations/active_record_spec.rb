RSpec.describe NxtStateMachine::ActiveRecord do
  context 'when used directly in a model' do
    let(:state_machine_class) do
      Class.new(Application) do
        include NxtStateMachine::ActiveRecord

        def self.name
          'Application'
        end

        state_machine(state_attr: :status) do
          state :received, initial: true
          state :processed, :accepted, :rejected

          event :process do
            transitions from: :received, to: :processed do |transition, processed_at, make_invalid: false|
              self.processed_at = processed_at
              self.received_at = nil if make_invalid
            end
          end

          event :accept do
            transitions from: :processed, to: :accepted do |transition, accepted_at|
              self.accepted_at = accepted_at
            end
          end

          event :accept_without_transaction, lock: false do
            transitions from: :processed, to: :accepted do |transition, accepted_at|
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
          expect(subject).to be_received
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
            expect(subject).to be_processed
          end
        end

        context 'when the record is not valid' do
          subject do
            state_machine_class.new
          end

          it do
            expect { subject.process(Time.current) }.to_not change { subject.status.to_s }
            expect { subject.process!(Time.current) }.to raise_error(ActiveRecord::RecordInvalid)
            expect(subject.status).to eq('received')
            expect(subject).to be_received
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
            expect(subject).to be_received
            expect { subject.process(Time.current) }.to change { subject.reload.status }.from('received').to('processed')
            expect(subject).to be_processed
            expect(subject.new_record?).to be_falsey
            expect { subject.accept!(Time.current) }.to change { subject.reload.status }.from('processed').to('accepted')
            expect(subject).to be_accepted
          end
        end

        context 'but the record is invalid' do
          subject do
            state_machine_class.create!(status: 'received', received_at: Time.current, content: 'some content')
          end

          it do
            expect { subject.process(Time.current, make_invalid: true) }.to_not change { subject.status.to_s }
            expect { subject.reload.process!(Time.current, make_invalid: true) }.to raise_error(ActiveRecord::RecordInvalid)
            expect(subject.reload.status).to eq('received')
            expect(subject).to be_received
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

              state_machine(state_attr: :status) do
                state :received, initial: true
                state :processed, :accepted, :rejected

                event :process do
                  before_transition from: :received, to: :processed do
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
            expect(subject).to be_received
            expect(subject.new_record?).to be_truthy

            expect { subject.process!(Time.current) }.to raise_error ZeroDivisionError
            expect(subject.status).to eq('received')
            expect(subject).to be_received
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

              state_machine(state_attr: :status) do
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
            expect(subject).to be_received

            expect { subject.process!(Time.current) }.to raise_error ZeroDivisionError
            expect(subject.new_record?).to be_truthy
            expect(subject.status).to eq('received')
            expect(subject).to be_received
          end
        end

        context 'in an after callback' do
          let(:state_machine_class) do
            Class.new(Application) do
              include NxtStateMachine::ActiveRecord

              def self.name
                'Application'
              end

              state_machine(state_attr: :status) do
                state :received, initial: true
                state :processed, :accepted, :rejected

                event :process do
                  transition from: :received, to: :processed do |t, processed_at|
                    self.processed_at = processed_at
                  end

                  after_transition from: :received, to: :processed do
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
            expect(subject).to be_received

            expect { subject.process!(Time.current) }.to raise_error ZeroDivisionError
            expect(subject.new_record?).to be_truthy
            expect(subject.status).to eq('received')
            expect(subject).to be_received
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

        state_machine(state_attr: :status, target: :application) do
          state :received, initial: true
          state :processed, :accepted, :rejected

          event :process do
            transition from: :received, to: :processed do |t, processed_at, make_invalid: false|
              application.processed_at = processed_at
              application.content = nil if make_invalid
            end
          end

          event :accept do
            transition from: :processed, to: :accepted do |t, accepted_at|
              application.accepted_at = accepted_at
            end
          end
        end

        state_machine.add_state_methods_to_model(Application)

        def reload
          application.reload
          self
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
          expect(subject.application).to be_received
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
            expect(application).to be_processed
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
            expect(subject).to be_received
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
            expect(subject).to be_accepted
          end
        end

        context 'when the record is invalid' do
          it do
            expect { subject.process(Time.current, make_invalid: true) }.to_not change { subject.application.status }
            expect { subject.reload.process!(Time.current, make_invalid: true) }.to raise_error ActiveRecord::RecordInvalid
            expect(subject.application.reload.status).to eq('received')
            expect(subject).to be_received
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

              state_machine(state_attr: :status, target: :application) do
                state :received, initial: true
                state :processed, :accepted, :rejected

                event :process do
                  before_transition from: :received, to: :processed do
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
            expect(subject).to be_received

            expect { subject.process!(Time.current) }.to raise_error ZeroDivisionError
            expect(subject.application).to be_new_record
            expect(subject.application.status).to eq('received')
            expect(subject).to be_received
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

              state_machine(state_attr: :status, target: :application) do
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
            expect(subject).to be_received

            expect { subject.process!(Time.current) }.to raise_error ZeroDivisionError
            expect(subject.application).to be_new_record
            expect(subject.application.status).to eq('received')
            expect(subject).to be_received
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

              state_machine(state_attr: :status, target: :application) do
                state :received, initial: true
                state :processed, :accepted, :rejected

                event :process do
                  transitions from: :received, to: :processed do |_, processed_at|
                    application.processed_at = processed_at
                  end

                  after_transition from: :received, to: :processed do
                    raise ZeroDivisionError, "oh oh"
                  end
                end

                event :accept do
                  transitions from: :processed, to: :accepted do |_, accepted_at|
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
            expect(subject).to be_received

            expect { subject.process!(Time.current) }.to raise_error ZeroDivisionError
            expect(subject.application).to be_new_record
            expect(subject.application.status).to eq('received')
            expect(subject).to be_received
          end
        end
      end

      context 'around callbacks' do
        let(:state_machine_class) do
          Class.new do
            include NxtStateMachine::ActiveRecord

            def initialize(application)
              @application = application
              @result = []
            end

            attr_reader :application, :result

            state_machine(state_attr: :status, target: :application) do
              state :received, initial: true
              state :processed

              event :process do
                transitions from: any_state, to: :processed do |processed_at:|
                  self.application.processed_at = Time.current
                end

                around_transition from: any_state, to: :processed do |block, transition|
                  append_result('first before')
                  block.call
                  append_result('first after')
                end

                around_transition from: any_state, to: :processed do |block|
                  append_result('second before')
                  block.call
                  append_result('second after')
                end
              end
            end

            def append_result(tmp)
              result << tmp
            end
          end
        end

        subject do
          state_machine_class.new(application)
        end

        let(:application) {
          Application.new(
            content: 'Please make it happen',
            received_at: Time.current
          )
        }

        context '#<event>' do
          it 'executes the callbacks in the correct order' do
            expect {
              subject.process(processed_at: Time.current)
            }.to change { subject.result }.from(be_empty).to(["first before", "second before", "second after", "first after"])
          end
        end

        context '#<event>!' do
          it 'executes the callbacks in the correct order' do
            expect {
              subject.process!(processed_at: Time.current)
            }.to change { subject.result }.from(be_empty).to(["first before", "second before", "second after", "first after"])
          end
        end
      end

      context 'success callbacks' do
        let(:state_machine_class) do
          Class.new do
            include NxtStateMachine::ActiveRecord

            def initialize(application)
              @application = application
            end

            attr_reader :application

            state_machine(state_attr: :status, target: :application) do
              state :received, initial: true
              state :processed, :accepted, :rejected

              event :process do
                transitions from: :received, to: :processed do |raise_in: ''|
                  application.processed_at = Time.current
                  raise_in
                end

                after_transition from: :received, to: :processed do |transition|
                  raise ZeroDivisionError, "After transition" if transition.result == 'raise_in_after_transition'
                end

                on_success from: :received, to: :processed do |transition|
                  raise ZeroDivisionError, "On success" if transition.result == 'raise_in_on_success'
                  accept!
                end
              end

              event :accept do
                transitions from: :processed, to: :accepted do
                  application.accepted_at = Time.current
                end
              end
            end
          end
        end

        let(:application) {
          Application.create!(
            content: 'Please make it happen',
            received_at: Time.current,
            status: 'received'
          )
        }

        subject do
          state_machine_class.new(application)
        end

        context 'when there is an error before' do
          it 'does not run the on success callback' do
            expect { subject.process!(raise_in: 'raise_in_after_transition') }.to raise_error(ZeroDivisionError, /After transition/)
            expect(application.reload.status).to eq('received')
          end
        end

        context 'when there is no error before' do
          context 'when there is an error in the success callback' do
            it do
              expect { subject.process!(raise_in: 'raise_in_on_success') }.to raise_error(ZeroDivisionError, /On success/)
              expect(application.reload.status).to eq('processed')
            end
          end

          context 'when triggering another transition' do
            it 'transitions to the next state' do
              expect { subject.process! }.to change { application.reload.status }.from('received').to('accepted')
            end
          end
        end
      end
    end
  end

  describe '#halt_transaction' do
    let(:state_machine_class) do
      Class.new do
        include NxtStateMachine::ActiveRecord

        def initialize(application)
          @application = application
        end

        attr_reader :application

        state_machine(state_attr: :status, target: :application) do
          state :received, initial: true
          state :processed, :accepted, :rejected

          event :process do
            before_transition from: any_state, to: :processed do
              halt_transition 'oh oh'
            end
            transitions from: any_state, to: :processed
          end

          event :accept do
            transitions from: any_state, to: :accepted do
              halt_transition 'oh oh', info: 'might be useful'
            end
          end

          event :reject do
            transitions from: any_state, to: :rejected

            after_transition from: any_state, to: :rejected do
              halt_transition 'oh oh', info: 'might be useful'
            end
          end
        end
      end
    end

    let(:application) {
      Application.new(
        content: 'Please make it happen',
        received_at: Time.current,
        rejected_at: Time.current,
        processed_at: Time.current
      )
    }

    subject do
      state_machine_class.new(application)
    end

    context 'before_transition callback' do
      context '#<event>' do
        it do
          expect(subject.process).to be_falsey
          expect { subject.process }.to_not change { subject.application.status }
          expect(application).to be_new_record
        end
      end

      context '#<event>!' do
        it do
          expect { subject.process! }.to raise_error NxtStateMachine::Errors::TransitionHalted
          expect(subject.application.status).to eq('received')
          expect(application).to be_new_record
        end
      end
    end

    context 'during the transition' do
      context '#<event>' do
        it do
          expect(subject.accept).to be_falsey
          expect { subject.accept }.to_not change { subject.application.status }
          expect(application).to be_new_record
        end
      end

      context '#<event>!' do
        it do
          expect { subject.accept! }.to raise_error NxtStateMachine::Errors::TransitionHalted
          expect(subject.application.status).to eq('received')
          expect(application).to be_new_record
        end
      end
    end

    context 'after_transition callback' do
      context '#<event>' do
        it do
          expect(subject.reject).to be_falsey
          expect { subject.reject }.to_not change { subject.application.status }
          expect(application).to be_new_record
        end
      end

      context '#<event>!' do
        it do
          expect { subject.reject! }.to raise_error NxtStateMachine::Errors::TransitionHalted
          expect(subject.application.status).to eq('received')
          expect(application).to be_new_record
        end
      end
    end
  end

  describe 'error callbacks' do
    let(:application) {
      Application.new(
        content: 'Handle this',
        received_at: Time.current
      )
    }

    subject do
      state_machine_class.new(application)
    end

    context 'when the callback applies to all transitions' do
      let(:state_machine_class) do
        Class.new do
          include NxtStateMachine::ActiveRecord

          def initialize(application)
            @application = application
            @result = nil
          end

          attr_reader :application
          attr_accessor :result

          state_machine(state_attr: :status, target: :application) do
            state :received, initial: true
            state :processed, :errored

            event :process do
              transitions from: :received, to: :processed do |error:, message:|
                raise error, message
              end
            end

            event :errored do
              transitions from: any_state, to: :errored do |error:, message:|
                raise error, message
              end
            end

            on_error from: any_state, to: all_states do |error|
              self.result = error
            end
          end
        end
      end

      it 'executes the callback on any kind of error' do
        subject.process!(error: StandardError, message: 'I can handle this')
        expect(subject.result.message).to eq('I can handle this')

        subject.errored!(error: StandardError, message: 'Errored')
        expect(subject.result.message).to eq('Errored')
      end
    end

    context 'when the callback applies to a specific transition only' do
      let(:state_machine_class) do
        Class.new do
          include NxtStateMachine::ActiveRecord

          def initialize(application)
            @application = application
            @result = nil
          end

          attr_reader :application
          attr_accessor :result

          state_machine(state_attr: :status, target: :application) do
            state :received, initial: true
            state :processed, :errored

            event :process do
              transitions from: :received, to: :processed do |error:, message:|
                raise error, message
              end
            end

            event :errored do
              transitions from: any_state, to: :errored do |error:, message:|
                raise error, message
              end
            end

            on_error from: all_states, to: :processed do |error|
              self.result = error
            end
          end
        end
      end

      context 'and the transition raises an error' do
        it 'executes the callback' do
          subject.process!(error: StandardError, message: 'I can handle this')
          expect(subject.result.message).to eq('I can handle this')
        end
      end

      context 'and another transition raises an error' do
        it 'does not execute the callback' do
          expect {
            subject.errored!(error: StandardError, message: 'I cannot handle this')
          }.to raise_error StandardError, 'I cannot handle this'
        end
      end
    end

    context 'when the callback applies to a specific kind of error only' do
      let(:state_machine_class) do
        Class.new do
          include NxtStateMachine::ActiveRecord

          def initialize(application)
            @application = application
            @result = nil
          end

          attr_reader :application
          attr_accessor :result

          state_machine(state_attr: :status, target: :application) do
            state :received, initial: true
            state :processed, :errored

            event :process do
              transitions from: :received, to: :processed do |error:, message:|
                raise error, message
              end

              on_error ZeroDivisionError, from: all_states, to: :processed do |error|
                self.result = error
              end
            end

            event :errored do
              transitions from: any_state, to: :errored do |error:, message:|
                raise error, message
              end
            end

            on_error ArgumentError, from: all_states, to: :errored do |error|
              self.result = error
            end
          end
        end
      end

      context 'and that kind of error is raised' do
        it 'executes the callback' do
          subject.process!(error: ZeroDivisionError, message: 'I can handle zero division')
          expect(subject.result.message).to eq('I can handle zero division')

          subject.errored!(error: ArgumentError, message: 'I can handle argument errors')
          expect(subject.result.message).to eq('I can handle argument errors')
        end
      end

      context 'and another kind of error is raised' do
        it 'does not execute the callback' do
          expect {
            subject.process!(error: StandardError, message: 'I cannot handle standard errors')
          }.to raise_error StandardError, 'I cannot handle standard errors'

          expect {
            subject.process!(error: ArgumentError, message: 'I cannot handle argument errors')
          }.to raise_error ArgumentError, 'I cannot handle argument errors'
        end
      end
    end
  end

  describe '#transitions' do
    let(:state_machine_class) do
      Class.new(Application) do
        include NxtStateMachine::ActiveRecord

        def self.name
          'Application'
        end

        state_machine(state_attr: :status) do
          state :received, initial: true
          state :processed, :accepted, :rejected

          event :process do
            transitions from: :received, to: :processed do |raise: false, halt: false|
              self.processed_at = Time.current
              raise ZeroDivisionError, 'oh oh' if raise
              halt_transition if halt
              'This will be returned'
            end
          end

          event :accept do
            transitions from: :processed, to: :accepted
          end
        end
      end
    end

    subject do
      state_machine_class.new(content: 'content is required', received_at: Time.current)
    end

    context 'with block' do
      context 'when successful' do
        context 'with bang' do
          it 'returns the value of the block' do
            expect(subject.process!).to eq('This will be returned')
          end
        end

        context 'without bang' do
          it 'returns the value of the block' do
            expect(subject.process).to eq('This will be returned')
          end
        end
      end

      context 'when not successful' do
        context 'with bang' do
          it 'raises an error' do
            expect { subject.process!(raise: true) }.to raise_error ZeroDivisionError
          end
        end

        context 'without bang' do
          it 'returns false' do
            expect(subject.process(halt: true)).to be_falsey
          end
        end
      end
    end

    context 'without block' do
      context 'when successful' do
        before do
          subject.process!
          subject.update!(accepted_at: Time.current)
        end

        context 'with bang' do
          it 'returns true' do
            expect(subject.accept!).to be_truthy
          end
        end

        context 'without bang' do
          it 'returns true' do
            expect(subject.accept).to be_truthy
          end
        end
      end

      context 'when not successful' do
        before do
          subject.process!
          subject.accepted_at = nil
        end

        context 'with bang' do
          it 'raises an error' do
            expect { subject.accept! }.to raise_error ActiveRecord::RecordInvalid
          end
        end

        context 'without bang' do
          it 'returns false' do
            expect(subject.accept).to be_falsey
          end
        end
      end
    end
  end

  describe '#ignore_errors' do
    let(:state_machine_class) do
      Class.new do
        include NxtStateMachine::ActiveRecord

        def initialize(application)
          @application = application
          @result = []
        end

        attr_reader :application, :result

        state_machine(state_attr: :status, target: :application) do
          state :received, initial: true
          state :processed
          state :checked

          event :process do
            defuse ZeroDivisionError, from: any_state, to: :processed

            transitions from: :received, to: :processed do
              application.update!(processed_at: Time.current)
              raise_zero_division_error
            end
          end

          event :check do
            transitions from: :received, to: :checked do
              application.update!(content: 'This is rolled back')
            end

            after_transition from: :received, to: :checked do
              raise_zero_division_error
            end
          end

          on_error from: any_state, to: all_states do |error|
            application.reload.update!(error: error)
          end
        end

        def raise_zero_division_error
          raise ZeroDivisionError, 'this is ok'
        end
      end
    end

    subject do
      state_machine_class.new(application)
    end

    let(:application) {
      Application.create!(
        content: 'Received',
        received_at: Time.current,
        status: :received
      )
    }

    it 'does not rollback the transaction on defused errors' do
      expect { subject.process! }.to change { application.reload.processed_at }.from(nil).to(be_a(Time))
      expect(application.error).to eq('this is ok')
      expect { subject.check! }.to_not change { application.reload.content }
    end

    it 'rolls back the transaction on non defused errors' do
      expect { subject.check! }.to_not change { application.reload.content }
    end
  end
end
