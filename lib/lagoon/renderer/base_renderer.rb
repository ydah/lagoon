# frozen_string_literal: true

module Lagoon
  module Renderer
    class BaseRenderer
      attr_reader :direction

      def initialize(direction: "TB")
        @direction = direction
      end

      def render(parsed_data)
        raise NotImplementedError, "Subclasses must implement #render"
      end

      protected

      def escape_class_name(name)
        # Mermaidで特殊文字を含むクラス名をエスケープ
        if name.match?(/[^a-zA-Z0-9_]/)
          "`#{name}`"
        else
          name
        end
      end

      def type_to_mermaid(type)
        # Ruby/Rails型をMermaid表記に変換
        case type.to_s
        when /integer/i then "Integer"
        when /string/i then "String"
        when /text/i then "Text"
        when /boolean/i then "Boolean"
        when /datetime/i then "DateTime"
        when /date/i then "Date"
        when /time/i then "Time"
        when /decimal/i then "Decimal"
        when /float/i then "Float"
        when /json/i then "JSON"
        else type.to_s.capitalize
        end
      end
    end
  end
end
