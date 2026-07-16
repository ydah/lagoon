# frozen_string_literal: true

module Lagoon
  module Renderer
    class ControllerModelErRenderer < BaseRenderer
      def initialize(options = {})
        super(direction: options[:direction] || 'TB')
        @show_actions = options.fetch(:show_actions, true)
      end

      def render(parsed_data)
        output = ['classDiagram', "    direction #{@direction}", '']

        relationships = parsed_data[:relationships] || []
        return output.join("\n").rstrip if relationships.empty?

        render_classes(output, relationships)
        output << ''

        relationships.sort_by { |rel| [rel[:controller].to_s, rel[:model].to_s] }.each do |rel|
          output << render_relationship(rel)
        end

        output.join("\n").rstrip
      end

      private

      def render_relationship(rel)
        controller = safe_identifier(rel[:controller])
        model = safe_identifier(rel[:model])
        actions = rel[:actions] || []
        label = @show_actions && actions.any? ? " : #{escape_label(actions.sort.join(', '))}" : ''

        "    #{controller} ..> #{model}#{label}"
      end

      def render_classes(output, relationships)
        controllers = relationships.filter_map { |rel| rel[:controller] }.uniq.sort
        models = relationships.filter_map { |rel| rel[:model] }.uniq.sort

        controllers.each { |name| output << "    class #{aliased_identifier(name)}" }
        models.each { |name| output << "    class #{aliased_identifier(name)}" }
      end
    end
  end
end
