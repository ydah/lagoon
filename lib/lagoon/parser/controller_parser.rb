# frozen_string_literal: true

module Lagoon
  module Parser
    class ControllerParser
      attr_reader :options, :config

      def initialize(options = {})
        @options = options.is_a?(Options) ? options : Options.for(:controller, options)
        @analyzer = Lagoon::Analyzer::ActionControllerAnalyzer.new
        @filter = ApplicationClassFilter.new(directory: "controllers", include_all: @options[:all_controllers])
      end

      def parse
        controllers = load_controllers
        classes = []
        relationships = []

        warnings = []

        controllers.sort_by { |controller| controller.name.to_s }.each do |controller|
          next if excluded?(controller)

          controller_data = @analyzer.analyze_controller(controller, analysis_options)
          classes << controller_data

          if options[:include_inheritance]
            relationships.concat(
              @analyzer.extract_inheritance(
                controller,
                include_framework_base: options[:include_framework_bases]
              )
            )
          end
        rescue StandardError => e
          raise if options[:strict]

          warnings << "Failed to analyze controller #{controller.name || '(anonymous)'}: #{e.message}"
        end

        {
          classes: classes.sort_by { |controller| controller[:name] },
          relationships: relationships.sort_by { |relationship| [relationship[:source], relationship[:target]] },
          warnings: warnings,
          counts: { classes: classes.size, relationships: relationships.size, skipped: warnings.size }
        }
      end

      private

      def load_controllers
        return [] unless defined?(ActionController::Base)

        Rails.application.eager_load! if options[:eager_load] && defined?(Rails)
        ActionController::Base.descendants
      end

      def excluded?(controller)
        controller_name = controller.name
        return true unless controller_name
        return true unless @filter.include?(controller)
        return true if options[:exclude].include?(controller_name)
        return !options[:specify].include?(controller_name) if options[:specify].any?

        false
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
