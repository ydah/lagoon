# frozen_string_literal: true

module Lagoon
  module Parser
    class SchemaParser
      ConnectionEntry = Data.define(:name, :connection)
      TableMetadata = Data.define(:name, :raw_name, :prefix, :columns, :primary_keys, :foreign_keys, :indexes)

      attr_reader :options

      def initialize(options = {})
        @options = options.is_a?(Options) ? options : Options.for(:er, options)
        @analyzer = Lagoon::Analyzer::DatabaseSchemaAnalyzer.new
      end

      def parse
        entities = []
        relationships = []
        warnings = []

        load_schema(warnings).each do |table|
          next if excluded?(table)

          analyze_table(table, entities, relationships)
        rescue StandardError => e
          raise if options[:strict]

          warnings << "Failed to analyze table #{table.name}: #{e.message}"
        end

        {
          entities: entities.sort_by { |entity| entity[:name] },
          relationships: relationships.sort_by { |relationship| [relationship[:source], relationship[:target]] },
          warnings: warnings,
          counts: { entities: entities.size, relationships: relationships.size, skipped: warnings.size }
        }
      end

      private

      def load_schema(warnings)
        entries = connection_entries
        multiple_connections = entries.size > 1

        entries.flat_map do |entry|
          load_connection_schema(entry, multiple_connections, warnings)
        end
      end

      def connection_entries
        configured = options[:connections]
        return normalize_configured_connections(configured) if configured
        return [] unless defined?(ActiveRecord::Base)

        pools = all_connection_pools
        connections = pools.filter_map do |pool|
          ConnectionEntry.new(name: connection_name(pool), connection: pool.connection)
        rescue ActiveRecord::ConnectionNotEstablished
          nil
        end
        base = ConnectionEntry.new(name: 'primary', connection: ActiveRecord::Base.connection)
        connections.unshift(base)
        connections.uniq { |entry| entry.connection.object_id }
      rescue NoMethodError
        [ConnectionEntry.new(name: 'primary', connection: ActiveRecord::Base.connection)]
      end

      def all_connection_pools
        handler = ActiveRecord::Base.connection_handler
        return handler.all_connection_pools if handler.respond_to?(:all_connection_pools)

        handler.connection_pool_list
      end

      def normalize_configured_connections(configured)
        pairs = configured.respond_to?(:to_h) ? configured.to_h : Array(configured).to_h
        pairs.map { |name, connection| ConnectionEntry.new(name: name.to_s, connection: connection) }
      rescue TypeError
        Array(configured).each_with_index.map do |connection, index|
          ConnectionEntry.new(name: "database_#{index + 1}", connection: connection)
        end
      end

      def load_connection_schema(entry, multiple_connections, warnings)
        connection = entry.connection
        prefix = multiple_connections ? entry.name : nil

        connection.tables.sort.filter_map do |table_name|
          next if @analyzer.internal_table?(table_name, internal_tables: options[:internal_tables])

          load_table_metadata(connection, table_name, prefix)
        rescue StandardError => e
          raise if options[:strict]

          warnings << "Failed to inspect table #{qualify(table_name, prefix)}: #{e.message}"
          nil
        end
      end

      def load_table_metadata(connection, table_name, prefix)
        TableMetadata.new(
          name: qualify(table_name, prefix),
          raw_name: table_name,
          prefix: prefix,
          columns: cached_columns(connection, table_name),
          primary_keys: primary_keys(connection, table_name),
          foreign_keys: connection.foreign_keys(table_name),
          indexes: connection.indexes(table_name)
        )
      end

      def cached_columns(connection, table_name)
        cache = connection.schema_cache
        cache.columns(table_name)
      rescue ArgumentError
        cache.columns(connection.pool, table_name)
      rescue NoMethodError
        connection.columns(table_name)
      end

      def primary_keys(connection, table_name)
        return Array(connection.primary_keys(table_name)) if connection.respond_to?(:primary_keys)

        Array(connection.primary_key(table_name))
      end

      def analyze_table(table, entities, relationships)
        entities << @analyzer.analyze_table(
          table.name,
          table.columns,
          primary_keys: table.primary_keys,
          foreign_keys: table.foreign_keys,
          indexes: table.indexes
        )
        relationships.concat(
          @analyzer.extract_foreign_keys(
            table.name,
            table.columns,
            foreign_keys: table.foreign_keys,
            indexes: table.indexes,
            primary_keys: table.primary_keys,
            table_prefix: table.prefix
          )
        )
      end

      def excluded?(table)
        return true if options[:exclude].include?(table.name) || options[:exclude].include?(table.raw_name)
        return false if options[:specify].empty?

        !options[:specify].include?(table.name) && !options[:specify].include?(table.raw_name)
      end

      def qualify(table_name, prefix)
        prefix ? "#{prefix}.#{table_name}" : table_name.to_s
      end

      def connection_name(pool)
        config = pool.respond_to?(:db_config) ? pool.db_config : nil
        parts = [config&.name]
        parts << pool.role if pool.respond_to?(:role)
        parts << pool.shard if pool.respond_to?(:shard)
        parts.compact.map(&:to_s).reject(&:empty?).join('_').then { |name| name.empty? ? 'database' : name }
      end
    end
  end
end
