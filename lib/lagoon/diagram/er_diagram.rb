# frozen_string_literal: true

module Lagoon
  module Diagram
    class ErDiagram < Base
      protected

      def diagram_kind
        :er
      end

      def parser
        @parser ||= Parser::SchemaParser.new(@options)
      end

      def renderer
        @renderer ||= Renderer::ErDiagramRenderer.new
      end

      def default_filename
        'er_diagram.mermaid'
      end
    end
  end
end
