# frozen_string_literal: true

require "active_support/core_ext/string"

module Lagoon
  module Parser
    class ModelParser
      attr_reader :options, :config

      def initialize(options = {})
        @options = options
        @config = Lagoon.configuration
        @analyzer = Lagoon::Analyzer::ActiveRecordAnalyzer.new
      end

      def parse
        models = load_models
        classes = []
        relationships = []

        models.each do |model|
          next if excluded?(model)

          # Use analyzer to extract model metadata
          model_data = @analyzer.analyze_model(model, analysis_options)
          classes << model_data

          # Use analyzer to extract relationships
          relationships.concat(@analyzer.extract_associations(model, analysis_options))
          relationships.concat(@analyzer.extract_inheritance(model)) if config.include_inheritance
        end

        {
          classes: classes,
          relationships: relationships
        }
      end

      private

      def load_models
        # Load all Rails models
        return [] unless defined?(Rails)

        Rails.application.eager_load!
        ActiveRecord::Base.descendants.reject(&:abstract_class?)
      end

      def excluded?(model)
        model_name = model.name
        config.exclude_models.include?(model_name)
      end

      def analysis_options
        {
          all_columns: options[:all_columns],
          hide_through: options[:hide_through],
          show_belongs_to: options[:show_belongs_to]
        }
      end
    end
  end
end
