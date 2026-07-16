# frozen_string_literal: true

module Lagoon
  module Renderer
    class ErDiagramRenderer < BaseRenderer
      def render(parsed_data)
        output = ["erDiagram"]

        if parsed_data[:relationships]&.any?
          parsed_data[:relationships].sort_by { |rel| relationship_sort_key(rel) }.each do |rel|
            output << render_relationship(rel)
          end
          output << ""
        end

        parsed_data.fetch(:entities, []).sort_by { |entity| entity[:name].to_s }.each do |entity|
          output << render_entity(entity)
        end

        output.join("\n").rstrip
      end

      private

      def render_entity(entity)
        lines = []
        entity_name = aliased_identifier(entity[:name], uppercase: true)

        lines << "    #{entity_name} {"
        entity.fetch(:attributes, []).sort_by { |attr| attr[:name].to_s }.each do |attr|
          type = type_to_er_type(attr[:type])
          constraints = []
          constraints << "PK" if attr[:primary_key]
          constraints << "FK" if attr[:foreign_key]
          constraints << "UK" if attr[:unique]

          line = "        #{safe_identifier(type)} #{safe_identifier(attr[:name])}"
          line += " #{constraints.join(',')}" if constraints.any?
          line += " #{mermaid_string(attr[:name])}" if safe_identifier(attr[:name]) != attr[:name].to_s
          lines << line
        end
        lines << "    }"
        lines << ""

        lines.join("\n")
      end

      def render_relationship(rel)
        source = safe_identifier(rel[:source], uppercase: true)
        target = safe_identifier(rel[:target], uppercase: true)
        label = rel[:label]

        source_card = cardinality_symbol(rel[:source_cardinality])
        target_card = cardinality_symbol(rel[:target_cardinality])

        line_type = rel[:identifying] ? "--" : ".."

        "    #{source} #{source_card}#{line_type}#{target_card} #{target} : #{mermaid_string(label)}"
      end

      def cardinality_symbol(cardinality)
        case cardinality&.to_sym
        when :one
          "||"
        when :zero_or_one
          "o|"
        when :one_or_more
          "}|"
        when :zero_or_many
          "o{"
        else
          raise ConfigurationError, "Unknown ER cardinality: #{cardinality.inspect}"
        end
      end

      def relationship_sort_key(relationship)
        %i[source target label].map { |key| relationship[key].to_s }
      end

      def type_to_er_type(type)
        # Ruby/Rails型をERダイアグラム用の型に変換
        case type.to_s.downcase
        when /integer/, /bigint/
          "int"
        when /string/, /varchar/
          "string"
        when /text/
          "text"
        when /boolean/
          "boolean"
        when /datetime/, /timestamp/
          "datetime"
        when /date/
          "date"
        when /time/
          "time"
        when /decimal/, /numeric/
          "decimal"
        when /float/, /double/
          "float"
        when /json/, /jsonb/
          "json"
        else
          type.to_s.downcase
        end
      end
    end
  end
end
