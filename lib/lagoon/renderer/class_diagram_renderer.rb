# frozen_string_literal: true

module Lagoon
  module Renderer
    class ClassDiagramRenderer < BaseRenderer
      def render(parsed_data)
        output = ["classDiagram"]
        output << "    direction #{@direction}"
        output << ""

        # クラス定義を追加
        parsed_data[:classes].each do |klass|
          output << render_class(klass)
        end

        output << ""

        # 関係性を追加
        parsed_data[:relationships].each do |rel|
          output << render_relationship(rel)
        end

        output.join("\n")
      end

      private

      def render_class(klass)
        lines = []
        class_name = escape_class_name(klass[:name])

        lines << "    class #{class_name} {"
        lines << "        <<abstract>>" if klass[:abstract]

        # 属性を追加
        if klass[:attributes]&.any?
          klass[:attributes].each do |attr|
            visibility = attr[:visibility] || "+"
            type = type_to_mermaid(attr[:type])
            lines << "        #{visibility}#{type} #{attr[:name]}"
          end
        end

        # メソッドを追加
        if klass[:methods]&.any?
          klass[:methods].each do |method|
            visibility = method[:visibility] || "+"
            return_type = method[:return_type] ? " #{type_to_mermaid(method[:return_type])}" : ""
            lines << "        #{visibility}#{method[:name]}()#{return_type}"
          end
        end

        lines << "    }"
        lines << ""
        lines.join("\n")
      end

      def render_relationship(rel)
        source = escape_class_name(rel[:source])
        target = escape_class_name(rel[:target])
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
        line += " : #{label}" if label
        line
      end
    end
  end
end
