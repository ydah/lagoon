# frozen_string_literal: true

require "active_support/core_ext/string"

module Lagoon
  module Parser
    class ModelParser
      attr_reader :options, :config

      def initialize(options = {})
        @options = options.is_a?(Options) ? options : Options.for(:model, options)
        @analyzer = Lagoon::Analyzer::ActiveRecordAnalyzer.new
        @filter = ApplicationClassFilter.new(directory: "models", include_all: @options[:all_models])
      end

      def parse
        models = load_models
        classes = []
        relationships = []

        warnings = []

        models.sort_by { |model| model.name.to_s }.each do |model|
          next if excluded?(model)

          analyze_model(model, classes, relationships)
        rescue StandardError => e
          raise if options[:strict]

          warnings << "Failed to analyze model #{model.name || '(anonymous)'}: #{e.message}"
        end

        normalized_relationships = deduplicate_relationships(relationships)
        {
          classes: classes.sort_by { |model| model[:name] },
          relationships: normalized_relationships,
          warnings: warnings,
          counts: { classes: classes.size, relationships: normalized_relationships.size, skipped: warnings.size }
        }
      end

      private

      def load_models
        return [] unless defined?(ActiveRecord::Base)

        Rails.application.eager_load! if options[:eager_load] && defined?(Rails)
        ActiveRecord::Base.descendants
      end

      def excluded?(model)
        model_name = model.name
        return true unless model_name
        return true unless @filter.include?(model)
        return true if options[:exclude].include?(model_name)
        return !options[:specify].include?(model_name) if options[:specify].any?

        false
      end

      def analysis_options
        {
          show_attributes: options[:show_attributes],
          show_methods: options[:show_methods],
          all_columns: options[:all_columns],
          hide_magic: options[:hide_magic],
          hide_through: options[:hide_through],
          show_belongs_to: options[:show_belongs_to],
          duplicate_sti_attributes: options[:duplicate_sti_attributes]
        }
      end

      def analyze_model(model, classes, relationships)
        classes << @analyzer.analyze_model(model, analysis_options)
        relationships.concat(@analyzer.extract_associations(model, analysis_options))
        return unless options[:include_inheritance]

        relationships.concat(
          @analyzer.extract_inheritance_with_options(
            model,
            include_framework_base: options[:include_framework_bases]
          )
        )
      end

      def deduplicate_relationships(relationships)
        relationships.group_by { |relationship| relationship_key(relationship) }.values.map do |duplicates|
          duplicates.min_by { |relationship| relationship[:macro] == :belongs_to ? 1 : 0 }
        end.sort_by { |relationship| relationship_key(relationship) }
      end

      def relationship_key(relationship)
        if relationship[:type] == :association && !relationship[:polymorphic]
          [relationship[:type].to_s, *[relationship[:source], relationship[:target]].sort]
        else
          [relationship[:type].to_s, relationship[:source].to_s, relationship[:target].to_s]
        end
      end
    end
  end
end
