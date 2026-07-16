# frozen_string_literal: true

require 'tmpdir'

RSpec.describe Lagoon::Diagram::Base do
  let(:parser) { instance_double('Parser', parse: { classes: [], relationships: [] }) }
  let(:renderer) { instance_double('Renderer', render: "classDiagram\n") }
  let(:diagram_class) do
    parser_instance = parser
    renderer_instance = renderer

    Class.new(described_class) do
      define_method(:diagram_kind) { :model }
      define_method(:default_filename) { 'test.mermaid' }
      define_method(:parser) { parser_instance }
      define_method(:renderer) { renderer_instance }
    end
  end

  around do |example|
    Dir.mktmpdir do |directory|
      @directory = directory
      example.run
    end
  end

  let(:configuration) do
    Lagoon::Configuration.new.tap { |config| config.output_dir = File.join(@directory, 'nested') }
  end
  let(:diagram) { diagram_class.new({}, configuration: configuration) }

  it 'normalizes options and snapshots configuration' do
    expect(diagram.options).to be_a(Lagoon::Options)
    expect(diagram.config).to equal(configuration)
  end

  it 'writes atomically and returns a structured result' do
    result = diagram.generate

    expect(result).to be_a(Lagoon::Result)
    expect(result.path).to eq(File.join(@directory, 'nested', 'test.mermaid'))
    expect(result.content).to eq("classDiagram\n")
    expect(File.read(result.path)).to eq(result.content)
  end

  it 'creates the parent of a custom output path' do
    path = File.join(@directory, 'custom', 'deep', 'diagram.mermaid')
    result = diagram_class.new({ output: path }, configuration: configuration).generate

    expect(result.path).to eq(path)
    expect(File).to exist(path)
    expect(File).not_to exist(configuration.output_dir)
  end
end
