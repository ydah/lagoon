# frozen_string_literal: true

RSpec.describe Lagoon::Analyzer::DatabaseSchemaAnalyzer do
  subject(:analyzer) { described_class.new }

  let(:columns) do
    [
      double('Column', name: 'uuid', type: :uuid, null: false),
      double('Column', name: 'creator_id', type: :integer, null: false),
      double('Column', name: 'legacy_id', type: :integer, null: true),
      double('Column', name: 'slug', type: :string, null: false)
    ]
  end
  let(:foreign_key) { double('ForeignKey', column: 'creator_id', to_table: 'users') }
  let(:unique_index) { double('Index', unique: true, columns: ['slug']) }

  describe '#analyze_table' do
    subject(:table) do
      analyzer.analyze_table(
        'posts',
        columns,
        primary_keys: ['uuid'],
        foreign_keys: [foreign_key],
        indexes: [unique_index]
      )
    end

    it 'uses actual primary key, foreign key, and unique metadata' do
      attributes = table[:attributes].to_h { |attribute| [attribute[:name], attribute] }

      expect(attributes['uuid'][:primary_key]).to be true
      expect(attributes['creator_id'][:foreign_key]).to be true
      expect(attributes['slug'][:unique]).to be true
    end

    it 'does not infer foreign keys from an _id suffix' do
      legacy_id = table[:attributes].find { |attribute| attribute[:name] == 'legacy_id' }

      expect(legacy_id[:foreign_key]).to be false
    end
  end

  describe '#extract_foreign_keys' do
    it 'orients a required one-to-many relationship from parent to child' do
      relationship = analyzer.extract_foreign_keys(
        'posts',
        columns,
        foreign_keys: [foreign_key],
        indexes: [],
        primary_keys: ['uuid']
      ).first

      expect(relationship).to include(
        source: 'users',
        target: 'posts',
        source_cardinality: :one,
        target_cardinality: :zero_or_many,
        identifying: false
      )
    end

    it 'uses nullability and a unique index for an optional one-to-one relationship' do
      optional_fk = double('ForeignKey', column: 'legacy_id', to_table: 'legacy_records')
      unique_fk = double('Index', unique: true, columns: ['legacy_id'])

      relationship = analyzer.extract_foreign_keys(
        'posts',
        columns,
        foreign_keys: [optional_fk],
        indexes: [unique_fk]
      ).first

      expect(relationship).to include(
        source_cardinality: :zero_or_one,
        target_cardinality: :zero_or_one,
        label: 'has one'
      )
    end

    it 'supports custom foreign key names and database prefixes' do
      relationship = analyzer.extract_foreign_keys(
        'primary.posts',
        columns,
        foreign_keys: [foreign_key],
        table_prefix: 'primary'
      ).first

      expect(relationship).to include(source: 'primary.users', target: 'primary.posts')
    end
  end

  describe '#internal_table?' do
    it 'uses a configurable list' do
      expect(analyzer.internal_table?('audit_metadata', internal_tables: ['audit_metadata'])).to be true
      expect(analyzer.internal_table?('schema_migrations', internal_tables: [])).to be false
    end
  end
end
