require 'json'
require 'active_support/all'

class Node
  attr_accessor :input_edges, :output_edges, :visitied, :options, :context

  def initialize(id, opts = {})
    @id = id
    @input_edges = []
    @output_edges = []
    @context = opts.dig(:context) || {}
    @options = opts.dig(:options) || {}
  end

  def inputs
    @inputs ||= @input_edges
      .map(&:from)
      .map(&:result)
      .flatten(1)
  end

  def result
    @result ||= begin
      v = call(*inputs)
      puts "#{self.class.name}: #{inputs} => #{v}"
      v
    end
  end

  def call(*values)
    raise 'implement me!'
  end
end

class Input < Node
  def call(*values)
    []
  end
end

class FromContext < Node
  def call(*values)
    [*values, *context.dig(options.dig(:key))]
  end
end

class Output < Node
  def call(*values)
    [values]
  end
end

class Sum < Node
  def call(*values)
    [values.compact.inject(&:+)]
  end
end

class Rand < Node
  def call(*values)
    [rand(0..10)]
  end
end

class TwoX < Node
  def call(*values)
    [values.first * 2]
  end
end

class Edge
  attr_accessor :from, :to

  def initialize(from:, to:)
    @from = from
    @to = to
  end
end

class Dag
  attr_accessor :nodes, :context

  def initialize(hash, context: {})
    @context = context
    @nodes = build_from_hash(hash)
  end

  def result
    nodes.dig(:output).result
  end

  private

  def build_from_hash(hash)
    nodes = hash
      .dig(:nodes)
      .map do |k, v|
        [
          k,
          Object.const_get(v.dig(:class)).new(
            k,
            options: v.dig(:options),
            context: @context,
          )
        ]
      end
      .to_h

    hash.dig(:edges).map do |e|
      from_node = nodes.dig(e.dig(:from).to_sym)
      to_node = nodes.dig(e.dig(:to).to_sym)

      edge = Edge.new(from: from_node, to: to_node)

      from_node.output_edges << edge
      to_node.input_edges << edge
    end

    nodes
  end
end

context = {
  "offset" => 100,
}

graph = JSON
  .parse(File.read('flow.json'))
  .deep_symbolize_keys

Dag
  .new(graph, context: context)
  .result
