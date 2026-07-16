# frozen_string_literal: true

module Lagoon
  module Diagram
    class ControllerDiagram < Base
      protected

      def diagram_kind
        :controller
      end

      def parser
        @parser ||= Parser::ControllerParser.new(@options)
      end

      def renderer
        @renderer ||= Renderer::ClassDiagramRenderer.new(direction: @options[:direction])
      end

      def default_filename
        "controllers.mermaid"
      end
    end
  end
end
