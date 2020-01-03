# NxtStateMachine

NxtStateMachine is a simple state machine library that ships with an easy to use integration for ActiveRecord.
It was build with the intend in mind to make it easy to implement other integrations. 
Beside the ActiveRecord integration, it ships with in memory adapters for Hash and attr_accessor.  

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

### ActiveRecord

In order to use nxt_state_machine with ActiveRecord simply `include NxtStateMachine::ActiveRecord` into your class.
This does not necessarily have to be a model (thus an instance of ActiveRecord) itself. If you are a fan of the single 
responsibility principle you might want to put your workflow logic in a separate class instead of into the model directly.
Therefore simply define the target of your state machine as follows. This enables you to split up complex workflows into 
multiple classes (maybe orchestrated by another toplevel workflow). If you do not provide a specific target, an instance 
of the class you include nxt_state_machine into will be the target (most likely your model).

#### Define which object holds you state with the target: option

```ruby
class Workflow
  include NxtStateMachine::ActiveRecord

  def initialize(article)
    @article = article
  end

  attr_reader :article

  state_machine(target: :article) do
    # ...
  end
end
```

#### Define which attribute holds you state with the state_attr: option

Customize which attribute is used to persist and fetch your state with `state_machine(state_attr: :state) do`. 
If this is not customized, nxt_state_machine assumes your target has a `:state` attribute.

### States

The initial state will be set on new records that do not yet have a state set. 
Of course there can only be one initial state.

```ruby
class Article < ApplicationRecord
  include NxtStateMachine::ActiveRecord
  
  state_machine do
    state :draft, initial: true
    states :written, :submitted
    # You can pass options to states that you can query in a transition later
    state :deleted, end_state: true

    # You can even define custom methods on states if options are not sufficient 
    state :advanced do
      def advanced_state?
        true
      end
    end
   end
end
```

### Events

Once you have defined your states you can define events and their transitions. Events trigger state transitions based
on the current state of your target.  

```ruby
class Article < ApplicationRecord
  include NxtStateMachine::ActiveRecord
  
  state_machine do
    state :draft, initial: true
    states :written, :approved, :rejected, :published 

    event :write do
      transition from: :draft, to: :written
      transition from: :rejected, to: :written
      # same as transition from: %i[draft rejected], to: :written
    end

    event :reject do
      transition from: all_states, to: :rejected # all_states is equivalent to any_state 
    end

    event :approve do
      # We recommend to use keyword arguments to make events accept custom arguments
      transition from: %i[written rejected], to: :approved do |approved_at:|
        self.approved_at = approved_at
        # NOTE: The transition is halted if this returns a falsey value
      end
    end
  end
end
```

The events above define the following methods in your workflow class.

```ruby
article.write
article.write!
# ...
# Generally speaking
article.<event_name> # will run the transition and call save on your target
article.<event_name!> # Will run the transition and call save! on your target

# Event that accepts keyword arguments
article.approve(approved_at: Time.current)
article.approve!(approved_at: Time.current)
```

*NOTE: In case an event accepts arguments (other than keyword arguments),
it will always be passed the current transition object as the first argument!*

```ruby
event :approve do
  transition from: %i[written rejected], to: :approved do |transition, approved_at:|
    # The transition object provides some useful information in the current transition
    puts transition.from # will give you the state object with the options and methods you defined earlier
    puts transition.to.enum # by calling :enum on the state it will give you the state enum 
  end
end
```

*NOTE* Transitions run in transactions that will be rolled back in case of an exception or if your target cannot be 
saved due to validation errors. The state is then set back to the state before the transition! 

#### Return values of transitions

If transitions take blocks, the transition will return the value of the block. This means that your block can return 
false and thus the return value of your transition is false even though the transition executed just fine! If a 
transition does not take a block, it will return the value of `:save` and `:save!` respectively.


### Callbacks

### Error Callbacks


### Putting it all together 

```ruby
class ArticleWorkflow
  include NxtStateMachine::ActiveRecord

  def initialize(article, **options)
    @article = article
    @options = options
  end

  attr_accessor :article

  state_machine(target: :article, state_attr: :status) do
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
      # When the block takes arguments (instead of only keyword arguments!!) 
      # the transition is always passed in as the first argument!!!
      transition from: %i[written rejected deleted], to: :submitted do |transition|
        puts transition.from.enum
        puts transition.to.enum
      end
    end

    event :approve do
      before_transition from: %i[written submitted deleted], to: :approved, run: :call_me_back

      transition from: %i[written submitted deleted], to: :approved do |headline:|
        article.headline = headline
      end

      after_transition from: %i[written submitted deleted], to: :approved, run: :call_me_back

      around_transition from: any_state, to: :approved do |block|
        # Note that around transition callbacks get passed a proc object that you have to call 
        puts 'around transition enter' 
        block.call  
        puts 'around transition exit'
      end

      on_error CustomError from: any_state, to: :approved do |error, transition|
      end
    end

    event :publish do
      before_transition from: any_state, to: :published, run: :some_method

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
    
    on_error! CustomError from: any_state, to: :approved do |error, transition|
      # Would overwrite an existing error handler 
    end
  end

  private

  def some_method
  end

  def call_me_back(transition)
    puts transition.from.enum
    puts transition.to.enum
  end
end
```

## TODO
- Test return values of transitions with and without block!!!
- What about inheritance? => What would be the expected behaviour? (dup vs. no dup)
    => Might also make sense to walk the ancestors chain and collect configure blocks
    => This might be super flexible as we could apply these in amend / reset mode
    => Probably would be best to have :amend_configuration and :reset_configuration methods on the state_machine 
- Test implementations for Hash, AttrAccessor

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/nxt_state_machine.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
