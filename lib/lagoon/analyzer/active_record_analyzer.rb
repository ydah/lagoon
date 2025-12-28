# frozen_string_literal: true

module Lagoon
  module Analyzer
    # Analyzes ActiveRecord models to extract metadata
    # including columns, methods, associations, and inheritance
    class ActiveRecordAnalyzer
      # Analyze a single model and return its metadata
      #
      # @param model [Class] ActiveRecord model class
      # @param options [Hash] Analysis options
      # @return [Hash] Model metadata
      def analyze_model(model, options = {})
        {
          name: model.name,
          abstract: model.abstract_class?,
          attributes: extract_columns(model, options),
          methods: extract_methods(model, options)
        }
      end

      # Extract associations from a model
      #
      # @param model [Class] ActiveRecord model class
      # @param options [Hash] Extraction options
      # @return [Array<Hash>] Association metadata
      def extract_associations(model, options = {})
        associations = []

        model.reflect_on_all_associations.each do |assoc|
          next if assoc.options[:through] && options[:hide_through]

          association_data = build_association(model, assoc, options)
          associations << association_data if association_data
        end

        associations
      end

      # Extract inheritance relationship from a model
      #
      # @param model [Class] ActiveRecord model class
      # @return [Array<Hash>] Inheritance metadata (empty or single element)
      def extract_inheritance(model)
        return [] if model.superclass == ActiveRecord::Base
        return [] if model.superclass.abstract_class?

        [{
          source: model.superclass.name,
          target: model.name,
          type: :inheritance,
          label: nil
        }]
      rescue StandardError
        []
      end

      private

      def extract_columns(model, options = {})
        return [] unless model.table_exists?

        columns = if options[:all_columns]
                    model.columns
                  else
                    model.columns.reject { |col| magic_field?(col.name, options) }
                  end

        columns.map do |column|
          {
            name: column.name,
            type: column.type,
            visibility: "+"
          }
        end
      end

      def magic_field?(field_name, options = {})
        # Magic fields (created_at, updated_at, etc.)
        return false if options[:all_columns]

        %w[id created_at updated_at].include?(field_name)
      end

      def extract_methods(_model, _options = {})
        # Extract public methods (implement as needed)
        []
      end

      def build_association(model, assoc, options = {})
        case assoc.macro
        when :belongs_to
          return nil unless options[:show_belongs_to]

          {
            source: model.name,
            target: assoc.class_name,
            type: :association,
            label: "belongs_to #{assoc.name}",
            source_cardinality: "1",
            target_cardinality: "0..1"
          }
        when :has_one
          {
            source: model.name,
            target: assoc.class_name,
            type: :association,
            label: "has_one #{assoc.name}",
            source_cardinality: "1",
            target_cardinality: "0..1"
          }
        when :has_many
          {
            source: model.name,
            target: assoc.class_name,
            type: :association,
            label: "has_many #{assoc.name}",
            source_cardinality: "1",
            target_cardinality: "*"
          }
        when :has_and_belongs_to_many
          {
            source: model.name,
            target: assoc.class_name,
            type: :association,
            label: "has_and_belongs_to_many #{assoc.name}",
            source_cardinality: "*",
            target_cardinality: "*"
          }
        end
      rescue NameError
        # Skip if association target class not found
        nil
      end
    end
  end
end
