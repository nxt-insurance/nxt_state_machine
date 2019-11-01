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

        state :draft, initial: true
        state :approved
        state :rejected

        event :approve do
          transition from: [:draft, :rejected], to: :approved do |**opts|
            mark_approved(opts)
          end
        end

        # after_transition from: all, to: :approved do
        #   reject if 1 == 2
        # end

        # before_transition from: all, to: :approved do
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
