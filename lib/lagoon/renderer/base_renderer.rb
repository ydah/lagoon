# frozen_string_literal: true

require 'digest'
require 'json'

module Lagoon
  module Renderer
    class BaseRenderer
      attr_reader :direction

      def initialize(direction: 'TB', **_options)
        @direction = Configuration.validate_direction!(direction)
      end

      def render(parsed_data)
        raise NotImplementedError, 'Subclasses must implement #render'
      end

      protected

      def escape_class_name(name)
        safe_identifier(name)
      end

      def safe_identifier(value, uppercase: false)
        original = value.to_s
        identifier = original.gsub(/[^a-zA-Z0-9_]/, '_').gsub(/_+/, '_')
        identifier = "_#{identifier}" unless identifier.match?(/\A[a-zA-Z_]/)
        identifier = "entity_#{Digest::SHA256.hexdigest(original)[0, 12]}" if identifier.empty? || identifier == '_'
        uppercase ? identifier.upcase : identifier
      end

      def aliased_identifier(value, uppercase: false)
        identifier = safe_identifier(value, uppercase: uppercase)
        display = uppercase ? value.to_s.upcase : value.to_s
        return identifier if identifier == display

        "#{identifier}[#{mermaid_string(display)}]"
      end

      def mermaid_string(value)
        JSON.generate(value.to_s.gsub(/[\r\n]+/, ' '))
      end

      def escape_member(value)
        value.to_s.gsub(/[\r\n]+/, ' ')
             .gsub('&', '&amp;')
             .gsub('"', '&quot;')
             .gsub('{', '&#123;')
             .gsub('}', '&#125;')
      end

      def escape_label(value)
        escape_member(value).gsub(':', '&#58;')
      end

      def type_to_mermaid(type)
        # Ruby/Rails型をMermaid表記に変換
        case type.to_s
        when /integer/i then 'Integer'
        when /string/i then 'String'
        when /text/i then 'Text'
        when /boolean/i then 'Boolean'
        when /datetime/i then 'DateTime'
        when /date/i then 'Date'
        when /time/i then 'Time'
        when /decimal/i then 'Decimal'
        when /float/i then 'Float'
        when /json/i then 'JSON'
        else type.to_s.capitalize
        end
      end
    end
  end
end
