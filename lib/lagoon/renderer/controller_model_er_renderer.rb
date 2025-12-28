# frozen_string_literal: true

module Lagoon
  module Renderer
    class ControllerModelErRenderer < BaseRenderer
      def initialize(options = {})
        super(direction: options[:direction] || "TB")
        @show_actions = options.fetch(:show_actions, true)
      end

      def render(parsed_data)
        output = ["erDiagram"]

        relationships = parsed_data[:relationships] || []
        return output.join("\n") if relationships.empty?

        # Group by controller for cleaner output
        by_controller = relationships.group_by { |r| r[:controller] }

        by_controller.each do |controller, controller_relationships|
          output << ""
          output << "    %% Controller: #{controller}"

          controller_relationships.each do |rel|
            output << render_relationship(rel)
          end
        end

        output.join("\n")
      end

      private

      def render_relationship(rel)
        controller = escape_class_name(rel[:controller])
        model = escape_class_name(rel[:model])
        actions = rel[:actions] || []

        # Relationship symbol: ||--o{ (controller "uses" models)
        # In ER diagram notation:
        # - || means "exactly one" on the controller side
        # - o{ means "zero or more" on the model side
        arrow = "||--o{"

        # Label with action names if enabled
        label = @show_actions && actions.any? ? actions.join(", ") : ""

        "    #{controller} #{arrow} #{model} : \"#{label}\""
      end
    end
  end
end
