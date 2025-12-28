# frozen_string_literal: true

module Lagoon
  module Parser
    class ControllerModelParser
      attr_reader :options, :config

      def initialize(options = {})
        @options = options
        @config = Lagoon.configuration
      end

      def parse
        controllers = load_controllers
        relationships = []

        controllers.each do |controller|
          next if excluded?(controller)
          next unless controller.name # Skip anonymous controllers

          actions = controller.action_methods.to_a
          next if actions.empty?

          source_file = find_controller_file(controller)
          next unless source_file && File.exist?(source_file)

          begin
            action_models = analyze_source_file(source_file, actions)

            action_models.each do |action, models|
              models.each do |model|
                relationships << {
                  controller: controller.name,
                  action: action,
                  model: model
                }
              end
            end
          rescue StandardError => e
            # Skip files that can't be parsed
            warn "Warning: Failed to parse #{source_file}: #{e.message}" if @options[:verbose]
          end
        end

        { relationships: aggregate_relationships(relationships) }
      end

      private

      def load_controllers
        # Railsアプリケーションの全コントローラをロード
        return [] unless defined?(Rails)

        Rails.application.eager_load!
        ActionController::Base.descendants
      end

      def excluded?(controller)
        controller_name = controller.name
        return true unless controller_name

        # Check global config
        return true if config.exclude_controllers.include?(controller_name)

        # Check command-line options
        if @options[:exclude]
          return true if @options[:exclude].include?(controller_name)
        end

        # If specify option is provided, only include specified controllers
        if @options[:specify]
          return !@options[:specify].include?(controller_name)
        end

        false
      end

      def find_controller_file(controller)
        # Derive file path from controller class name
        # User::PostsController → app/controllers/user/posts_controller.rb
        # UsersController → app/controllers/users_controller.rb
        path = controller.name.underscore + ".rb"
        Rails.root.join("app", "controllers", path)
      rescue StandardError
        nil
      end

      def analyze_source_file(file_path, action_names)
        require_relative "../analyzer/ast_model_reference_analyzer"
        analyzer = Lagoon::Analyzer::AstModelReferenceAnalyzer.new
        result = analyzer.analyze(file_path, action_names)

        # Convert Set to Array for easier handling
        result.transform_values(&:to_a)
      end

      def aggregate_relationships(relationships)
        # Group by [controller, model] and collect actions
        grouped = relationships.group_by { |r| [r[:controller], r[:model]] }

        grouped.map do |(controller, model), items|
          {
            controller: controller,
            model: model,
            actions: items.map { |i| i[:action] }.sort.uniq
          }
        end
      end
    end
  end
end
