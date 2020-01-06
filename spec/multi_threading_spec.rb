RSpec.describe NxtStateMachine do
  context 'multi threading' do
    let(:state_machine_class) do
      Class.new do
        include NxtStateMachine::AttrAccessor

        def initialize(status: nil)
          @status = status
        end

        attr_accessor :status, :processed_at, :accepted_at

        state_machine(state_attr: :status) do
          state :received, initial: true
          state :processed

          event :process do
            transitions from: :received, to: :processed do |processed_at:|
              sleep_a_while
              self.processed_at = processed_at
              sleep_a_while
            end
          end
        end

        def sleep_a_while
          sleep(rand(0)/10.0)
        end
      end
    end

    let(:thread_count) { 10_000 }

    let(:targets) do
      thread_count.times.each_with_object({}) do |index, acc|
        acc[index] = state_machine_class.new
      end
    end

    let(:threads) { [] }

    it 'is thread safe' do
      thread_count.times do |index|
        threads[index] = Thread.new {
          targets[index].process!(processed_at: "thread #{index}")
        }
      end

      threads.map(&:join)

      # Check if all transitions have the expected result - meaning one transition runs in isolation of another one
      targets.each do |k,v|
        expect(v.processed_at).to eq("thread #{k}")
      end
    end
  end
end
