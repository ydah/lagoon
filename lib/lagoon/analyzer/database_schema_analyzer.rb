# frozen_string_literal: true

require "active_support/core_ext/string"

module Lagoon
  module Analyzer
    # Analyzes database schema to extract table and column metadata
    class DatabaseSchemaAnalyzer
      # Analyze a single table and return its metadata
      #
      # @param table_name [String] Table name
      # @param columns [Array] Array of column objects
      # @return [Hash] Table metadata
      def analyze_table(table_name, columns)
        {
          name: table_name,
          attributes: columns.map { |col| analyze_column(col) }
        }
      end

      # Analyze a single column and return its metadata
      #
      # @param column [Object] Column object from ActiveRecord
      # @return [Hash] Column metadata
      def analyze_column(column)
        {
          name: column.name,
          type: column.type,
          primary_key: column.name == "id",
          foreign_key: foreign_key?(column.name),
          unique: false # Can be enhanced with actual unique constraints
        }
      end

      # Extract foreign key relationships from table columns
      #
      # @param table_name [String] Table name
      # @param columns [Array] Array of column objects
      # @return [Array<Hash>] Foreign key relationship metadata
      def extract_foreign_keys(table_name, columns)
        relationships = []

        columns.each do |column|
          next unless foreign_key?(column.name)

          # Infer target table from column name (e.g., user_id -> users)
          target_table = infer_target_table(column.name)
          next unless target_table

          relationships << {
            source: table_name,
            target: target_table,
            label: "has many",
            source_cardinality: "||",
            target_cardinality: "}o",
            identifying: true
          }
        end

        relationships
      end

      # Check if a table is an internal Rails table
      #
      # @param table_name [String] Table name
      # @return [Boolean] True if internal table
      def internal_table?(table_name)
        %w[schema_migrations ar_internal_metadata].include?(table_name)
      end

      private

      def foreign_key?(column_name)
        column_name.end_with?("_id")
      end

      def infer_target_table(foreign_key_name)
        # Infer: user_id -> users
        base_name = foreign_key_name.sub(/_id$/, "")
        base_name.pluralize
      rescue StandardError
        nil
      end
    end
  end
end
