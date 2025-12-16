# frozen_string_literal: true

module Lagoon
  module Renderer
    class ErDiagramRenderer < BaseRenderer
      def render(parsed_data)
        output = ["erDiagram"]

        # リレーションシップを先に追加
        if parsed_data[:relationships]&.any?
          parsed_data[:relationships].each do |rel|
            output << render_relationship(rel)
          end
          output << ""
        end

        # エンティティ定義を追加
        parsed_data[:entities].each do |entity|
          output << render_entity(entity)
        end

        output.join("\n")
      end

      private

      def render_entity(entity)
        lines = []
        entity_name = entity[:name].upcase

        lines << "    #{entity_name} {"
        entity[:attributes].each do |attr|
          type = type_to_er_type(attr[:type])
          constraints = []
          constraints << "PK" if attr[:primary_key]
          constraints << "FK" if attr[:foreign_key]
          constraints << "UK" if attr[:unique]

          line = "        #{type} #{attr[:name]}"
          line += " #{constraints.join(" ")}" if constraints.any?
          lines << line
        end
        lines << "    }"
        lines << ""

        lines.join("\n")
      end

      def render_relationship(rel)
        source = rel[:source].upcase
        target = rel[:target].upcase
        label = rel[:label]

        # カーディナリティを決定
        source_card = cardinality_symbol(rel[:source_cardinality])
        target_card = cardinality_symbol(rel[:target_cardinality])

        # 関係の種類（識別 or 非識別）
        line_type = rel[:identifying] ? "--" : ".."

        "    #{source} #{source_card}#{line_type}#{target_card} #{target} : \"#{label}\""
      end

      def cardinality_symbol(cardinality)
        case cardinality
        when "1", "one"
          "||"
        when "0..1", "zero_or_one"
          "|o"
        when "1..*", "one_or_more"
          "}|"
        when "*", "0..*", "zero_or_more", "many"
          "}o"
        else
          "||" # デフォルト
        end
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
