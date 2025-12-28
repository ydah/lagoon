# frozen_string_literal: true

require "active_support/core_ext/string"

module Lagoon
  module Parser
    class SchemaParser
      attr_reader :options, :config

      def initialize(options = {})
        @options = options
        @config = Lagoon.configuration
        @analyzer = Lagoon::Analyzer::DatabaseSchemaAnalyzer.new
      end

      def parse
        tables = load_schema
        entities = []
        relationships = []

        tables.each do |table_name, columns|
          next if excluded?(table_name)

          # Use analyzer to extract table metadata
          entity = @analyzer.analyze_table(table_name, columns)
          entities << entity

          # Use analyzer to extract foreign key relationships
          relationships.concat(@analyzer.extract_foreign_keys(table_name, columns))
        end

        {
          entities: entities,
          relationships: relationships
        }
      end

      private

      def load_schema
        return {} unless defined?(ActiveRecord)

        connection = ActiveRecord::Base.connection
        tables_hash = {}

        connection.tables.each do |table_name|
          next if @analyzer.internal_table?(table_name)

          columns = connection.columns(table_name)
          tables_hash[table_name] = columns
        end

        tables_hash
      end

      def excluded?(_table_name)
        false # Can be enhanced with exclusion logic
      end
    end
  end
end
