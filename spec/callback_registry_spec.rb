RSpec.describe NxtStateMachine::CallbackRegistry do
  subject { described_class.new }

  it do
    expect(subject[:from]).to be_a(NxtStateMachine::Registry)
    expect(subject[:from][:to]).to be_a(NxtStateMachine::Registry)
    expect(subject[:from][:to][:before]).to be_a(Array)
  end

  describe '#register' do
    it 'registers callbacks' do
      subject.register([:from_first, :from_second], :to_here, :before, :a1)
      expect(subject[:from_first][:to_here][:before]).to eq([:a1])
      expect(subject[:from_second][:to_here][:before]).to eq([:a1])
    end
  end

  describe '#resolve' do
    before do
      subject.register([:from_first, :from_second], :to_here, :before, :a1)
    end

    let(:transition) { OpenStruct.new(from: :from_second, to: :to_here) }

    it 'fetches the callbacks' do
      expect(subject.resolve(transition)[:before]).to eq([:a1])
      expect(subject.resolve(transition)[:after]).to be_empty
    end
  end
end
