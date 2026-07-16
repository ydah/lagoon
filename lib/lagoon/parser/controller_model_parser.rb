# frozen_string_literal: true

require "active_support/core_ext/string/inflections"

module Lagoon
  module Parser
    class ControllerModelParser
      attr_reader :options

      def initialize(options = {})
        @options = options.is_a?(Options) ? options : Options.for(:controller_model, options)
        @filter = ApplicationClassFilter.new(
          directory: "controllers",
          include_all: @options[:all_controllers]
        )
      end

      def parse
        relationships = []
        warnings = []
        model_metadata = load_model_metadata(warnings)

        load_controllers.sort_by { |controller| controller.name.to_s }.each do |controller|
          next if excluded?(controller)

          analyze_controller(controller, model_metadata, relationships, warnings)
        end

        aggregated = aggregate_relationships(relationships)
        {
          relationships: aggregated,
          warnings: warnings,
          counts: { relationships: aggregated.size, skipped: warnings.size }
        }
      end

      private

      def load_controllers
        return [] unless defined?(ActionController::Base)

        Rails.application.eager_load! if options[:eager_load] && defined?(Rails)
        ActionController::Base.descendants
      end

      def load_model_metadata(warnings)
        return { names: [], associations: {} } unless defined?(ActiveRecord::Base)

        models = ActiveRecord::Base.descendants.select(&:name)
        associations = models.to_h do |model|
          [model.name, association_mapping(model, warnings)]
        end
        { names: models.map(&:name), associations: associations }
      end

      def association_mapping(model, warnings)
        model.reflect_on_all_associations.each_with_object({}) do |association, result|
          next if association.options[:polymorphic]

          result[association.name.to_s] = association.class_name
        rescue NameError => e
          warnings << "Could not resolve #{model.name}.#{association.name}: #{e.message}"
        end
      end

      def excluded?(controller)
        controller_name = controller.name
        return true unless controller_name
        return true unless @filter.include?(controller)
        return true if options[:exclude].include?(controller_name)
        return !options[:specify].include?(controller_name) if options[:specify].any?

        false
      end

      def analyze_controller(controller, model_metadata, relationships, warnings)
        actions = controller.action_methods.to_a.map(&:to_s).sort
        return if actions.empty?

        source_context = source_context_for(controller, actions)
        if source_context[:files].empty?
          warnings << "No source file found for #{controller.name}"
          return
        end

        action_models = analyze_source_files(
          source_context[:files],
          actions,
          source_context[:controller_names],
          model_metadata
        )
        add_relationships(controller.name, action_models, relationships)
      rescue Errno::ENOENT, Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError, ParseError => e
        raise if options[:strict]

        warnings << "Failed to parse #{controller.name}: #{e.message}"
      end

      def source_context_for(controller, actions)
        owners = actions.filter_map do |action|
          controller.instance_method(action).owner
        rescue NameError
          nil
        end
        owners << controller
        owners.concat(callback_owners(controller))
        owners.select!(&:name)

        {
          controller_names: owners.map(&:name).uniq,
          files: owners.flat_map { |owner| source_files_for(owner) }.compact.uniq.select { |file| File.file?(file) }
        }
      end

      def source_files_for(controller)
        method_names = controller.instance_methods(false) +
                       controller.private_instance_methods(false) +
                       controller.protected_instance_methods(false)
        files = method_names.filter_map do |method_name|
          controller.instance_method(method_name).source_location&.first
        end
        constant_location = constant_source_location(controller)
        files << constant_location if constant_location
        files << conventional_source_file(controller) if files.empty?
        files
      rescue NameError
        [conventional_source_file(controller)]
      end

      def constant_source_location(controller)
        namespace_name = controller.name.deconstantize
        namespace = namespace_name.empty? ? Object : namespace_name.safe_constantize
        namespace&.const_source_location(controller.name.demodulize.to_sym)&.first
      end

      def conventional_source_file(controller)
        return nil unless defined?(Rails) && Rails.respond_to?(:root)

        Rails.root.join("app", "controllers", "#{controller.name.underscore}.rb").to_s
      end

      def callback_methods(controller)
        return [] unless controller.respond_to?(:_process_action_callbacks)

        controller._process_action_callbacks.filter_map do |callback|
          callback.filter.to_s if callback.filter.is_a?(Symbol)
        end.uniq
      end

      def callback_owners(controller)
        callback_methods(controller).filter_map do |method_name|
          controller.instance_method(method_name).owner
        rescue NameError
          nil
        end
      end

      def analyze_source_files(file_paths, action_names, controller_names, model_metadata)
        require_relative "../analyzer/ast_model_reference_analyzer"
        analyzer = Lagoon::Analyzer::AstModelReferenceAnalyzer.new
        analyzer.analyze(
          file_paths,
          action_names,
          controller_names: controller_names,
          model_names: model_metadata[:names],
          associations: model_metadata[:associations],
          helper_models: options[:helper_models]
        )
      end

      def add_relationships(controller_name, action_models, relationships)
        action_models.each do |action, models|
          models.each do |model|
            relationships << { controller: controller_name, action: action, model: model }
          end
        end
      end

      def aggregate_relationships(relationships)
        grouped = relationships.group_by { |relationship| [relationship[:controller], relationship[:model]] }

        grouped.map do |(controller, model), items|
          {
            controller: controller,
            model: model,
            actions: items.map { |item| item[:action] }.sort.uniq
          }
        end.sort_by { |relationship| [relationship[:controller], relationship[:model]] }
      end
    end
  end
end
