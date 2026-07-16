# frozen_string_literal: true

module Lagoon
  module Renderer
    class ClassDiagramRenderer < BaseRenderer
      def initialize(direction: "TB", show_types: true)
        super(direction: direction)
        @show_types = show_types
      end

      def render(parsed_data)
        output = ["classDiagram"]
        output << "    direction #{@direction}"
        output << ""

        classes = parsed_data.fetch(:classes, []).select { |klass| klass[:name] }
        classes.sort_by { |klass| klass[:name].to_s }.each do |klass|
          output << render_class(klass)
        end

        output << ""

        relationships = parsed_data.fetch(:relationships, []).select { |rel| rel[:source] && rel[:target] }
        relationships.sort_by { |rel| relationship_sort_key(rel) }.each do |rel|
          output << render_relationship(rel)
        end

        output.join("\n").rstrip
      end

      private

      def render_class(klass)
        lines = []
        class_name = aliased_identifier(klass[:name])

        lines << "    class #{class_name} {"
        lines << "        <<abstract>>" if klass[:abstract]

        if klass[:attributes]&.any?
          klass[:attributes].sort_by { |attr| attr[:name].to_s }.each do |attr|
            visibility = attr[:visibility] || "+"
            type = type_to_mermaid(attr[:type])
            prefix = @show_types ? "#{type} " : ""
            lines << "        #{visibility}#{prefix}#{escape_member(attr[:name])}"
          end
        end

        if klass[:methods]&.any?
          klass[:methods].sort_by { |method| [method[:visibility].to_s, method[:name].to_s] }.each do |method|
            visibility = method[:visibility] || "+"
            return_type = method[:return_type] ? " #{type_to_mermaid(method[:return_type])}" : ""
            lines << "        #{visibility}#{escape_member(method[:name])}()#{return_type}"
          end
        end

        lines << "    }"
        lines << ""
        lines.join("\n")
      end

      def render_relationship(rel)
        source = safe_identifier(rel[:source])
        target = safe_identifier(rel[:target])
        type = rel[:type]
        label = rel[:label]
        source_cardinality = rel[:source_cardinality]
        target_cardinality = rel[:target_cardinality]

        arrow = case type
                when :inheritance
                  "<|--"
                when :composition
                  "*--"
                when :aggregation
                  "o--"
                when :association
                  "-->"
                when :dependency
                  "..>"
                else
                  "--"
                end

        line = "    #{source}"
        line += " \"#{source_cardinality}\"" if source_cardinality
        line += " #{arrow} "
        line += "\"#{target_cardinality}\" " if target_cardinality
        line += target
        line += " : #{escape_label(label)}" if label && !label.to_s.empty?
        line
      end

      def relationship_sort_key(relationship)
        %i[source target type label].map { |key| relationship[key].to_s }
      end
    end
  end
end
