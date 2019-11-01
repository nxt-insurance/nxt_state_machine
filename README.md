# NxtStateMachine

```ruby

class ApplicationWorkflow
  include NxtStateMachine
  
  def initialize(application)
    @application = application
  end
  
  # This could also be a method that comes from include NxtStateMachine and then captures "self" in order to
  # execute the transitions in the scope of "self"  
  # state_machine should be a config that can be called multiple times like in pipeline!
  
  state_machine(:application) do
    transition_with do |from, to| 
      # all blocks should be evaluated within the "self"
      @application.update(state: to)
    end
    
    transition_with! do |from, to| 
      # all blocks should be evaluated within the "self"
      @application.update!(state: to)
    end
    
    before_transition from: any, to: :rejected do |**attributes|
      # all blocks should be evaluated within the "self"
      # we should allow to define attributes or not
    end
    
    after_transition from: all, to: :rejected do
          # all blocks should be evaluated within the "self"
    end
    
    # draft -|---|- approve -|---|-> appr-|-oved -|---- - -
  
    state :draft, initial: true
    state :review_pending
    state :approved do |state|
      state.guard do
        halt if 1 == 2  
      end
    end
    
    state :rejected
    
    event :request_review do
      transition from: :draft, to: :draft do |**attributes|
        
      end
    
      # transitions from: :draft, to: :draft
      # transitions from: :review_pending, to: :review_pending
    
      @application.attributes = attributes
      # reject if ...
    end
    
    event :approve, from: :review_pending, to: :approved # without block just updates the state
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
