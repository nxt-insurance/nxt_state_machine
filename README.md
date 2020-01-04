[![CircleCI](https://circleci.com/gh/nxt-insurance/nxt_state_machine.svg?style=svg)](https://circleci.com/gh/nxt-insurance/nxt_state_machine)

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

### ActiveRecord Example

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

### ActiveRecord

In order to use nxt_state_machine with ActiveRecord simply `include NxtStateMachine::ActiveRecord` into your class.
This does not necessarily have to be a model (thus an instance of ActiveRecord) itself. If you are a fan of the single 
responsibility principle you might want to put your workflow logic in a separate class instead of into the model directly.
Therefore simply define the target of your state machine as follows. This enables you to split up complex workflows into 
multiple classes (maybe orchestrated by another toplevel workflow). If you do not provide a specific target, an instance 
of the class you include nxt_state_machine into will be the target (most likely your model).

#### Define which object holds your state with the target: option

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

#### Define which attribute holds your state with the state_attr: option

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

**NOTE:** Transitions run in transactions that will be rolled back in case of an exception or if your target cannot be 
saved due to validation errors. The state is then set back to the state before the transition! 

### Transitions

When your transition takes arguments other than keyword arguments, it will always be passed the transition object itself
as the first argument. You can of course still accept keyword arguments. The transition object gives you access to the 
state objects with `transition.from` and `transition.to`. Now you can query the options and methods you've defined 
on those states earlier.  

```ruby
event :approve do
  transition from: %i[written rejected], to: :approved do |transition, approved_at:|
    # The transition object provides some useful information in the current transition
    puts transition.from # will give you the state object with the options and methods you defined earlier
    puts transition.from.options # options hash
    puts transition.to.enum # by calling :enum on the state it will give you the state enum 
    halt_transition if approved_at < 3.days.ago # This would halt the transition
    "This is the return value if there is no error"
  end
end
```

#### Return values of transitions

Be aware that transitions that take blocks, return the return value of the block! This means that when your block returns 
false, the transition would return false, even though the transition was executed just fine! (In that case is not equal 
to tranistion did not succeed) If a transition does not take a block, it will return the value of `:save` and `:save!` 
respectively.

#### Halting transitions

Transitions can be halted in callbacks and during the transition itself simply by calling `halt_transition`

### Callbacks

You can register `before_transition`, `around_transition` and `after_transition` callbacks. By defining the 
:from and :to states you decide on which transitions the callback actually runs. Around callbacks need to call the
proc object that they get passed in. Registering callbacks inside an event block or on the state_machine top level
behavious exactly the same way and is only a matter of structure. The only thing that defines when callbacks run is
the :from and :to parameters with which they are registered.
   

```ruby
event :approve do
  before_transition from: %i[written submitted deleted], to: :approved, run: :call_me_back

  transition from: %i[written submitted deleted], to: :approved 

  after_transition from: %i[written submitted deleted], to: :approved, run: :call_me_back

  around_transition from: any_state, to: :approved do |block|
    # Note that around transition callbacks get passed a proc object that you have to call 
    puts 'around transition enter' 
    block.call  
    puts 'around transition exit'
  end
end
```

### Error Callbacks

You can also register callbacks that run in case of an error occurs. By defining the error class you can restrict
error callbacks to run on certain errors only. Error callbacks are applied in the order they are registered. You 
can also overwrite previously registered errors with the bang method `on_error! CustomError ...`. By omitting the 
error class a error callback is registered for all errors that inherit from `StandardError`.

```ruby
state_machine do 
  # ...
  event :approve do
    transition from: %i[written submitted deleted], to: :approved do |headline:|
      article.headline = headline
    end
        
    on_error CustomError from: any_state, to: :approved do |error, transition|
      # do something about the error here 
    end
  end
    
  on_error! CustomError from: any_state, to: :approved do |error, transition|
    # overwrites previously registered error callbacks 
  end
end
```

### Multiple state machines in the same class

In theory you can also have multiple state_machines in the same class. To do so you have to give each 
state_machine a name. Events need to be unique globally in order to determine which state_machine will be called. 
You can also trigger events from one another.  

```ruby
class Article < ApplicationRecord
  include NxtStateMachine::ActiveRecord
  
  state_machine(:workflow) do
    state :draft, initial: true
    states :written, :approved, :rejected, :published 
    # ...    
  end

  state_machine(:error_handling) do
    # events need to be unique globally
  end
end
``` 


## TODO
- Test implementations for Hash, AttrAccessor
- What about inheritance? => What would be the expected behaviour? (dup vs. no dup)
    => Might also make sense to walk the ancestors chain and collect configure blocks
    => This might be super flexible as we could apply these in amend / reset mode
    => Probably would be best to have :amend_configuration and :reset_configuration methods on the state_machine 


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/nxt_state_machine.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
