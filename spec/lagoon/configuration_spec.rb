# frozen_string_literal: true

RSpec.describe Lagoon::Configuration do
  subject(:configuration) { described_class.new }

  describe '#initialize' do
    it 'sets default output_dir' do
      expect(configuration.output_dir).to eq('doc/diagrams')
    end

    it 'sets default diagram_direction' do
      expect(configuration.diagram_direction).to eq('TB')
    end

    it 'sets default show_attributes' do
      expect(configuration.show_attributes).to be true
    end

    it 'sets default show_methods' do
      expect(configuration.show_methods).to be false
    end

    it 'sets default include_inheritance' do
      expect(configuration.include_inheritance).to be true
    end

    it 'sets default exclude_models' do
      expect(configuration.exclude_models).to eq([])
    end

    it 'sets default exclude_controllers' do
      expect(configuration.exclude_controllers).to eq([])
    end

    it 'sets default internal tables' do
      expect(configuration.internal_tables).to contain_exactly('schema_migrations', 'ar_internal_metadata')
    end
  end

  describe 'attribute accessors' do
    it 'allows setting output_dir' do
      configuration.output_dir = 'custom/path'
      expect(configuration.output_dir).to eq('custom/path')
    end

    it 'allows setting diagram_direction' do
      configuration.diagram_direction = 'LR'
      expect(configuration.diagram_direction).to eq('LR')
    end

    it 'allows setting show_attributes' do
      configuration.show_attributes = false
      expect(configuration.show_attributes).to be false
    end

    it 'allows setting show_methods' do
      configuration.show_methods = true
      expect(configuration.show_methods).to be true
    end

    it 'allows setting include_inheritance' do
      configuration.include_inheritance = false
      expect(configuration.include_inheritance).to be false
    end

    it 'allows setting exclude_models' do
      configuration.exclude_models = %w[User Post]
      expect(configuration.exclude_models).to eq(%w[User Post])
    end

    it 'allows setting exclude_controllers' do
      configuration.exclude_controllers = ['ApplicationController']
      expect(configuration.exclude_controllers).to eq(['ApplicationController'])
    end

    it 'rejects invalid directions' do
      expect { configuration.diagram_direction = 'sideways' }
        .to raise_error(Lagoon::ConfigurationError, /Invalid diagram direction/)
    end
  end
end
