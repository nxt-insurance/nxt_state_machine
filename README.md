# NxtStateMachine

## TODO
- Should all states always be symbols or strings?
- Get rid of default callback order and make all methods available on transition
- Test that events with the same name can coexist but are unique!
- Test :around_transition callback chain for all integrations
- What about inheritance? => What would be the expected behaviour? (dup vs. no dup)
    => Might also make sense to walk the ancestors chain and collect configure blocks
    => This might be super flexible as we could apply these in amend / reset mode
    => Probably would be best to have :amend_configuration and :reset_configuration methods on the state_machine 
- Check if having multiple state machines in the same class is a big issue
- Reevaluate the return value of the transition? What would you expect?
- Add method to walk a path ? => Could this be done with the pipeline?!
- What about :on_error callbacks? => Do we need to implement this?  
- Halt transition probably also make sense for non active record default adapter
- Default implementation should also return proper values and reset the state in case of errors
- Write implementations for Hash, AttrAccessor

```ruby
class ArticleWorkflow
  include NxtStateMachine::ActiveRecord

  def initialize(article, **options)
    @article = article
    @options = options
  end

  attr_accessor :article

  active_record_state_machine(scope: :article, state: :status) do
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
      before_transition from: %i[written submitted deleted], to: :approved, call: :call_me_back

      transition from: %i[written submitted deleted], to: :approved do |headline:|
        article.headline = headline
      end

      after_transition from: %i[written submitted deleted], to: :approved, call: :call_me_back

      around_transition from: any_state, to: :approved do |block|
        # Note that around transition callbacks get passed a proc 
        # Thus you have to do `block.call` instead of yield
        puts 'around transition enter' 
        block.call  
        puts 'around transition exit'
      end
    end

    event :publish do
      before_transition from: any_state, to: :published do
        halt_transition if Time.current < Date.yesterday
      end

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
end

```

Welcome to your new gem! In this directory, you'll find the files you need to be able to package up your Ruby library into a gem. Put your Ruby code in the file `lib/nxt_state_machine`. To experiment with that code, run `bin/console` for an interactive prompt.

TODO: Delete this and the text above, and describe your gem

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'nxt_state_machine'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install nxt_state_machine

## Usage

TODO: Write usage instructions here

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/nxt_state_machine.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
