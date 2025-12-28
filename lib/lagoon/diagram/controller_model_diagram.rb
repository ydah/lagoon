# frozen_string_literal: true

require "fileutils"

module Lagoon
  module Diagram
    class ControllerModelDiagram < Base
      def generate
        parser = Parser::ControllerModelParser.new(@options)
        parsed_data = parser.parse

        renderer = Renderer::ControllerModelErRenderer.new(
          direction: @options[:direction] || @config.diagram_direction,
          show_actions: @options.fetch(:show_actions, true)
        )
        content = renderer.render(parsed_data)

        output_file = @options[:output] || output_path
        ensure_output_directory
        File.write(output_file, content)

        output_file
      end

      protected

      def default_filename
        "controller_models.mermaid"
      end
    end
  end
end
