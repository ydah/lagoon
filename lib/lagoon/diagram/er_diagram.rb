# frozen_string_literal: true

require "fileutils"

module Lagoon
  module Diagram
    class ErDiagram < Base
      def generate
        parser = Parser::SchemaParser.new(@options)
        parsed_data = parser.parse

        renderer = Renderer::ErDiagramRenderer.new(
          direction: @options[:direction] || @config.diagram_direction
        )
        content = renderer.render(parsed_data)

        output_file = @options[:output] || output_path
        ensure_output_directory
        File.write(output_file, content)

        output_file
      end

      protected

      def default_filename
        "er_diagram.mermaid"
      end
    end
  end
end
