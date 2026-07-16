# frozen_string_literal: true

module Lagoon
  module Diagram
    class ControllerModelDiagram < Base
      protected

      def diagram_kind
        :controller_model
      end

      def parser
        @parser ||= Parser::ControllerModelParser.new(@options)
      end

      def renderer
        @renderer ||= Renderer::ControllerModelErRenderer.new(
          direction: @options[:direction],
          show_actions: @options[:show_actions]
        )
      end

      def default_filename
        "controller_models.mermaid"
      end
    end
  end
end
