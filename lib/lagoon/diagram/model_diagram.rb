# frozen_string_literal: true

module Lagoon
  module Diagram
    class ModelDiagram < Base
      protected

      def diagram_kind
        :model
      end

      def parser
        @parser ||= Parser::ModelParser.new(@options)
      end

      def renderer
        @renderer ||= Renderer::ClassDiagramRenderer.new(
          direction: @options[:direction],
          show_types: !@options[:hide_types]
        )
      end

      def default_filename
        'models.mermaid'
      end
    end
  end
end
