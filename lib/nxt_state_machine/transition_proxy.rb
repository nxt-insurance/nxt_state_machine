class TransitionProxy
  def initialize(context, around_callbacks = [])
    @context = context
    @around_callbacks = around_callbacks
  end

  def call(&proxy)
    if around_callbacks.any?
      around_callback_chain(proxy).call
    else
      proxy.call
    end
  end

  private

  def around_callback_chain(proxy)
    around_callbacks.map { |c| NxtStateMachine::Callable.new(c).with_context(context) }.reverse.inject(proxy) do |previous, callback|
      -> { callback.call(previous) }
    end
  end

  attr_reader :proxy, :context, :around_callbacks
end
