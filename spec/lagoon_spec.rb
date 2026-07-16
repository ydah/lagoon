# frozen_string_literal: true

RSpec.describe Lagoon do
  it 'has a version number' do
    expect(Lagoon::VERSION).not_to be_nil
  end

  describe '.configuration' do
    it 'returns a Configuration instance' do
      expect(described_class.configuration).to be_a(Lagoon::Configuration)
    end
  end

  describe '.configure' do
    it 'yields the configuration' do
      expect { |b| described_class.configure(&b) }.to yield_with_args(Lagoon::Configuration)
    end

    it 'allows setting configuration options' do
      described_class.configure do |config|
        config.output_dir = 'custom/path'
      end

      expect(described_class.configuration.output_dir).to eq('custom/path')
    end
  end

  describe '.reset_configuration!' do
    it 'restores defaults without mutating an in-flight snapshot' do
      described_class.configuration.output_dir = 'custom/path'
      snapshot = described_class.configuration.dup

      described_class.reset_configuration!

      expect(described_class.configuration.output_dir).to eq('doc/diagrams')
      expect(snapshot.output_dir).to eq('custom/path')
    end
  end

  describe '.generate_all' do
    it 'treats output as a directory and uses distinct filenames' do
      allow(described_class).to receive(:generate_model_diagram) { |options| options[:output] }
      allow(described_class).to receive(:generate_controller_diagram) { |options| options[:output] }
      allow(described_class).to receive(:generate_er_diagram) { |options| options[:output] }
      allow(described_class).to receive(:generate_controller_model_diagram) { |options| options[:output] }

      results = described_class.generate_all(output: 'tmp/diagrams')

      expect(results.values).to contain_exactly(
        'tmp/diagrams/models.mermaid',
        'tmp/diagrams/controllers.mermaid',
        'tmp/diagrams/er_diagram.mermaid',
        'tmp/diagrams/controller_models.mermaid'
      )
    end
  end
end
