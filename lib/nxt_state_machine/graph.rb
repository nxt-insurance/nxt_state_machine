module NxtStateMachine
  class Graph
    def initialize(state_machines, **options)
      @state_machines = state_machines
      @options = default_options.merge(**options)
    end

    def draw
      require 'ruby-graphviz'

      state_machines.each do |_, state_machine|
        add_nodes(state_machine)
        add_edges(state_machine)
      end

      filename = File.join(options[:path], "#{options[:name]}.#{options[:format]}")

      graph.output options[:format] => filename

      puts '----------------------------------------------'
      puts 'Please run the following to open the generated file:'
      puts "open '#{filename}'"
      puts '----------------------------------------------'

      graph
    end

    private

    attr_reader :options, :state_machines

    def graph
      @graph ||= ::GraphViz.new(
        'G',
        rankdir: options[:orientation] == 'landscape' ? 'LR' : 'TB',
        ratio: options[:ratio]
      )
    end

    def add_nodes(state_machine)
      binding.pry
      state_machine.states.values.each do |state|
        add_node(state)
      end
    end

    def add_node(state)
      node_options = {
        label: state.to_s,
        width: '1',
        height: '1',
        shape: 'ellipse'
      }

      graph.add_nodes(state.to_s, node_options)
    end

    def add_edges(state_machine)
      state_machine.events.values.each do |event|
        event.event_transitions.values.each do |transition|
          graph.add_edges(transition.from.to_s, transition.to.to_s, label: event.name)
        end
      end
    end

    def default_options
      {
        name: 'state_machine',
        path: '.',
        orientation: 'landscape',
        ratio: 'fill',
        format: 'png',
        font: 'Helvetica'
      }
    end
  end
end
