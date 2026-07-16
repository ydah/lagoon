# frozen_string_literal: true

require 'logger'
require 'active_support'
require_relative 'lagoon/version'
require_relative 'lagoon/errors'
require_relative 'lagoon/result'
require_relative 'lagoon/configuration'
require_relative 'lagoon/options'
require_relative 'lagoon/diagram/base'
require_relative 'lagoon/diagram/model_diagram'
require_relative 'lagoon/diagram/controller_diagram'
require_relative 'lagoon/diagram/er_diagram'
require_relative 'lagoon/diagram/controller_model_diagram'
require_relative 'lagoon/analyzer/active_record_analyzer'
require_relative 'lagoon/analyzer/action_controller_analyzer'
require_relative 'lagoon/analyzer/database_schema_analyzer'
require_relative 'lagoon/parser/application_class_filter'
require_relative 'lagoon/parser/model_parser'
require_relative 'lagoon/parser/controller_parser'
require_relative 'lagoon/parser/schema_parser'
require_relative 'lagoon/parser/controller_model_parser'
require_relative 'lagoon/renderer/base_renderer'
require_relative 'lagoon/renderer/class_diagram_renderer'
require_relative 'lagoon/renderer/er_diagram_renderer'
require_relative 'lagoon/renderer/controller_model_er_renderer'
require_relative 'lagoon/railtie' if defined?(Rails::Railtie)

module Lagoon
  class << self
    attr_writer :configuration

    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def reset_configuration!
      @configuration = Configuration.new
    end

    def generate_model_diagram(options = {})
      Diagram::ModelDiagram.new(options, configuration: configuration.dup).generate
    end

    def generate_controller_diagram(options = {})
      Diagram::ControllerDiagram.new(options, configuration: configuration.dup).generate
    end

    def generate_er_diagram(options = {})
      Diagram::ErDiagram.new(options, configuration: configuration.dup).generate
    end

    def generate_controller_model_diagram(options = {})
      Diagram::ControllerModelDiagram.new(options, configuration: configuration.dup).generate
    end

    def generate_all(options = {})
      raw_options = options.to_h.transform_keys(&:to_sym)
      validate_all_options!(raw_options)
      eager_load_application!
      output_dir = raw_options.delete(:output)

      {
        models: generate_model_diagram(options_for(:model, raw_options, output_dir, 'models.mermaid')),
        controllers: generate_controller_diagram(
          options_for(:controller, raw_options, output_dir, 'controllers.mermaid')
        ),
        er: generate_er_diagram(options_for(:er, raw_options, output_dir, 'er_diagram.mermaid')),
        controller_models: generate_controller_model_diagram(
          options_for(:controller_model, raw_options, output_dir, 'controller_models.mermaid')
        )
      }
    end

    private

    def eager_load_application!
      Rails.application.eager_load! if defined?(Rails) && Rails.respond_to?(:application)
    end

    def validate_all_options!(options)
      allowed = Options::KEYS.values.flatten.uniq + [:output]
      unknown = options.keys - allowed
      return if unknown.empty?

      raise ConfigurationError, "Unknown all option(s): #{unknown.sort.join(', ')}"
    end

    def options_for(kind, options, output_dir, filename)
      selected = options.slice(*Options.allowed_keys(kind))
      selected[:eager_load] = false
      selected[:output] = File.join(output_dir.to_s, filename) if output_dir
      selected
    end
  end
end
