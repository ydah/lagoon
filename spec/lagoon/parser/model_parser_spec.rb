# frozen_string_literal: true

RSpec.describe Lagoon::Parser::ModelParser do
  let(:model) { double('Model', name: 'User') }

  describe 'filtering' do
    it 'supports exclude and specify and drops anonymous models' do
      parser = described_class.new(all_models: true, exclude: ['Audit'], specify: %w[User Audit])

      expect(parser.send(:excluded?, model)).to be false
      expect(parser.send(:excluded?, double('Audit', name: 'Audit'))).to be true
      expect(parser.send(:excluded?, double('Other', name: 'Other'))).to be true
      expect(parser.send(:excluded?, double('Anonymous', name: nil))).to be true
    end
  end

  describe 'normalized analysis options' do
    it 'honors brief and hide_magic' do
      parser = described_class.new(all_models: true, brief: true, hide_magic: true)
      analyzer = instance_double(Lagoon::Analyzer::ActiveRecordAnalyzer)
      allow(parser).to receive(:load_models).and_return([model])
      parser.instance_variable_set(:@analyzer, analyzer)
      allow(analyzer).to receive(:extract_associations).and_return([])
      allow(analyzer).to receive(:extract_inheritance_with_options).and_return([])

      expect(analyzer).to receive(:analyze_model).with(
        model,
        hash_including(show_attributes: false, show_methods: false, hide_magic: true)
      ).and_return(name: 'User', abstract: false, attributes: [], methods: [])

      parser.parse
    end
  end

  describe 'relationship normalization' do
    it 'deduplicates inverse associations and prefers the has_many description' do
      parser = described_class.new(all_models: true)
      relationships = [
        { source: 'Post', target: 'User', type: :association, macro: :belongs_to, label: 'belongs_to user' },
        { source: 'User', target: 'Post', type: :association, macro: :has_many, label: 'has_many posts' }
      ]

      expect(parser.send(:deduplicate_relationships, relationships)).to contain_exactly(
        hash_including(macro: :has_many, label: 'has_many posts')
      )
    end
  end

  describe 'error handling' do
    it 'continues with a warning by default and raises in strict mode' do
      analyzer = instance_double(Lagoon::Analyzer::ActiveRecordAnalyzer)
      allow(analyzer).to receive(:analyze_model).and_raise('broken model')

      parser = described_class.new(all_models: true)
      allow(parser).to receive(:load_models).and_return([model])
      parser.instance_variable_set(:@analyzer, analyzer)
      expect(parser.parse[:warnings]).to include(/broken model/)

      strict_parser = described_class.new(all_models: true, strict: true)
      allow(strict_parser).to receive(:load_models).and_return([model])
      strict_parser.instance_variable_set(:@analyzer, analyzer)
      expect { strict_parser.parse }.to raise_error(RuntimeError, 'broken model')
    end
  end
end
