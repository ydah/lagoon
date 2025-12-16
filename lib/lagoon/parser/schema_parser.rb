# frozen_string_literal: true

require "active_support/core_ext/string"

module Lagoon
  module Parser
    class SchemaParser
      attr_reader :options, :config

      def initialize(options = {})
        @options = options
        @config = Lagoon.configuration
      end

      def parse
        tables = load_schema
        entities = []
        relationships = []

        tables.each do |table_name, columns|
          next if excluded?(table_name)

          entity = parse_table(table_name, columns)
          entities << entity
          relationships.concat(extract_foreign_keys(table_name, columns))
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
          next if internal_table?(table_name)

          columns = connection.columns(table_name)
          tables_hash[table_name] = columns
        end

        tables_hash
      end

      def internal_table?(table_name)
        # Railsの内部テーブルをスキップ
        %w[schema_migrations ar_internal_metadata].include?(table_name)
      end

      def excluded?(_table_name)
        false # 必要に応じて除外ロジックを追加
      end

      def parse_table(table_name, columns)
        {
          name: table_name,
          attributes: columns.map { |col| parse_column(col) }
        }
      end

      def parse_column(column)
        {
          name: column.name,
          type: column.type,
          primary_key: column.name == "id",
          foreign_key: foreign_key?(column.name),
          unique: false # 必要に応じて実装
        }
      end

      def foreign_key?(column_name)
        column_name.end_with?("_id")
      end

      def extract_foreign_keys(table_name, columns)
        relationships = []

        columns.each do |column|
          next unless foreign_key?(column.name)

          # column_nameから参照先テーブルを推測 (例: user_id -> users)
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

      def infer_target_table(foreign_key_name)
        # user_id -> users のように推測
        base_name = foreign_key_name.sub(/_id$/, "")
        base_name.pluralize
      rescue StandardError
        nil
      end
    end
  end
end
