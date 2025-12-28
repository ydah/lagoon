# frozen_string_literal: true

module Lagoon
  module Parser
    class ControllerParser
      attr_reader :options, :config

      def initialize(options = {})
        @options = options
        @config = Lagoon.configuration
        @analyzer = Lagoon::Analyzer::ActionControllerAnalyzer.new
      end

      def parse
        controllers = load_controllers
        classes = []
        relationships = []

        controllers.each do |controller|
          next if excluded?(controller)

          # Use analyzer to extract controller metadata
          controller_data = @analyzer.analyze_controller(controller, analysis_options)
          classes << controller_data

          # Use analyzer to extract inheritance
          relationships.concat(@analyzer.extract_inheritance(controller)) if config.include_inheritance
        end

        {
          classes: classes,
          relationships: relationships
        }
      end

      private

      def load_controllers
        # Load all Rails controllers
        return [] unless defined?(Rails)

        Rails.application.eager_load!
        ActionController::Base.descendants
      end

      def excluded?(controller)
        controller_name = controller.name
        config.exclude_controllers.include?(controller_name)
      end

      def analysis_options
        {
          hide_public: options[:hide_public],
          hide_protected: options[:hide_protected],
          hide_private: options[:hide_private]
        }
      end
    end
  end
end
