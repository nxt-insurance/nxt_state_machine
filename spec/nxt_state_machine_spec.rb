RSpec.describe NxtStateMachine do

  let(:application) do
    Class.new do
      include NxtStateMachine

      def initialize
        @application = {}
      end

      attr_accessor :application

      state_machine do
        # transition_with do |from, to|
        #   self.state = to
        # end

        state :pending, initial: true
        state :revised
        state :approved
        state :published
        state :deleted
        state :rejected

        event :revise do
          transition from: :pending, to: :revised do |**opts|
            mark_approved(opts)
          end
        end

        event :reject do
          transition from: %i[revised approved], to: :rejected do |**opts|
            mark_approved(opts)
          end
        end

        event :reject do
          transition from: %i[pending revised approved], to: :rejected do |**opts|
            mark_approved(opts)
          end
        end

        event :delete do
          transition from: any_state, to: :deleted do |**opts|
            mark_approved(opts)
          end
        end

        # after_transition from: any_state, to: :approved do
        #   reject if 1 == 2
        # end

        # before_transition from: all_states, to: :approved do
        #   reject if 1 == 2
        # end
      end

      def mark_approved(opts)
        puts opts
      end
    end
  end

  subject do
    application.new
  end

  describe '.state' do
    it do
      binding.pry
    end
  end
end
