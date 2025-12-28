# frozen_string_literal: true

require_relative "lagoon/version"
require_relative "lagoon/configuration"
require_relative "lagoon/diagram/base"
require_relative "lagoon/diagram/model_diagram"
require_relative "lagoon/diagram/controller_diagram"
require_relative "lagoon/diagram/er_diagram"
require_relative "lagoon/diagram/controller_model_diagram"
require_relative "lagoon/analyzer/active_record_analyzer"
require_relative "lagoon/analyzer/action_controller_analyzer"
require_relative "lagoon/analyzer/database_schema_analyzer"
require_relative "lagoon/analyzer/ast_model_reference_analyzer"
require_relative "lagoon/parser/model_parser"
require_relative "lagoon/parser/controller_parser"
require_relative "lagoon/parser/schema_parser"
require_relative "lagoon/parser/controller_model_parser"
require_relative "lagoon/renderer/base_renderer"
require_relative "lagoon/renderer/class_diagram_renderer"
require_relative "lagoon/renderer/er_diagram_renderer"
require_relative "lagoon/renderer/controller_model_er_renderer"
require_relative "lagoon/railtie" if defined?(Rails::Railtie)

module Lagoon
  class Error < StandardError; end

  class << self
    attr_writer :configuration

    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def generate_model_diagram(options = {})
      Diagram::ModelDiagram.new(options).generate
    end

    def generate_controller_diagram(options = {})
      Diagram::ControllerDiagram.new(options).generate
    end

    def generate_er_diagram(options = {})
      Diagram::ErDiagram.new(options).generate
    end

    def generate_controller_model_diagram(options = {})
      Diagram::ControllerModelDiagram.new(options).generate
    end

    def generate_all(options = {})
      {
        models: generate_model_diagram(options),
        controllers: generate_controller_diagram(options),
        er: generate_er_diagram(options),
        controller_models: generate_controller_model_diagram(options)
      }
    end
  end
end
