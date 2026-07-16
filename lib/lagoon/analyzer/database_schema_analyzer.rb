# frozen_string_literal: true

module Lagoon
  module Analyzer
    class DatabaseSchemaAnalyzer
      def analyze_table(table_name, columns, primary_keys: [], foreign_keys: [], indexes: [])
        foreign_key_columns = foreign_keys.flat_map { |foreign_key| Array(foreign_key.column).map(&:to_s) }
        unique_columns = single_column_unique_indexes(indexes)
        primary_key_columns = Array(primary_keys).map(&:to_s)

        {
          name: table_name,
          attributes: columns.map do |column|
            analyze_column(
              column,
              primary_keys: primary_key_columns,
              foreign_keys: foreign_key_columns,
              unique_columns: unique_columns
            )
          end
        }
      end

      def analyze_column(column, primary_keys: [], foreign_keys: [], unique_columns: [])
        {
          name: column.name,
          type: column.type,
          primary_key: primary_keys.include?(column.name.to_s),
          foreign_key: foreign_keys.include?(column.name.to_s),
          unique: unique_columns.include?(column.name.to_s)
        }
      end

      def extract_foreign_keys(table_name, columns, foreign_keys:, indexes: [], primary_keys: [], table_prefix: nil)
        columns_by_name = columns.to_h { |column| [column.name.to_s, column] }
        unique_columns = single_column_unique_indexes(indexes)
        primary_key_columns = Array(primary_keys).map(&:to_s)

        foreign_keys.filter_map do |foreign_key|
          column_names = Array(foreign_key.column).map(&:to_s)
          foreign_key_columns = column_names.filter_map { |name| columns_by_name[name] }
          next if foreign_key_columns.empty?

          unique = column_names.size == 1 && unique_columns.include?(column_names.first)
          nullable = foreign_key_columns.any? { |column| column.respond_to?(:null) ? column.null : true }
          identifying = (column_names - primary_key_columns).empty?

          {
            source: qualify_table(foreign_key.to_table, table_prefix),
            target: table_name,
            label: unique ? "has one" : "has many",
            source_cardinality: nullable ? :zero_or_one : :one,
            target_cardinality: unique ? :zero_or_one : :zero_or_many,
            identifying: identifying,
            foreign_key: column_names
          }
        end
      end

      def internal_table?(table_name, internal_tables: %w[schema_migrations ar_internal_metadata])
        internal_tables.include?(table_name.to_s)
      end

      private

      def single_column_unique_indexes(indexes)
        indexes.select { |index| index.unique && Array(index.columns).size == 1 }
               .map { |index| Array(index.columns).first.to_s }
      end

      def qualify_table(table_name, prefix)
        return table_name.to_s unless prefix

        "#{prefix}.#{table_name}"
      end
    end
  end
end
