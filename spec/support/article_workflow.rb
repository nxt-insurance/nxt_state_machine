class ArticleWorkflow
  include NxtStateMachine

  def initialize(article)
    @article = article
  end

  attr_accessor :article

  # ar_state_machine(state: :status, scope: :self) do
  #
  # end

  state_machine do
    get_state_with do
      article.status = initial_state.name if article.new_record?
      article.status
    end

    set_state_with do |from, to, transition, callbacks|
      article.transaction do
        callbacks[:before].each { |callback| callback.run(self) }

        transition.call
        article.status = to

        if article.save
          callbacks[:after].each { |callback| callback.run(self) }
        end
      end
    end

    set_state_with! do |from, to, transition|
      transition.call
      article.status = to
      article.save!
    end

    state :draft, initial: true
    state :written
    state :submitted
    state :approved
    state :published
    state :rejected
    state :deleted

    event :write do
      transition from: %i[draft written deleted], to: :written
    end

    event :submit do
      transition from: %i[written rejected deleted], to: :submitted
    end

    event :approve do
      before_transition from: %i[written submitted deleted], run: :call_me_back

      transition from: %i[written submitted deleted], to: :approved do |headline:|
        article.headline = headline
      end

      after_transition from: :submitted do
        puts '------------------'
        puts '------------------'
        puts '------------------'
        puts '------------------'
        puts '------------------'
      end
    end

    event :publish do
      transition from: :approved, to: :published
    end

    event :reject do
      transition from: %i[draft submitted deleted], to: :rejected
    end

    event :delete do
      transition from: any_state, to: :deleted do
        article.deleted_at = Time.current
      end
    end
  end

  def call_me_back
    puts '***********'
    puts '***********'
    puts '***********'
    puts '***********'
    puts '***********'
  end
end
