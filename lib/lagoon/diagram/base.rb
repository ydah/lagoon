# frozen_string_literal: true

require 'fileutils'
require 'tempfile'

module Lagoon
  module Diagram
    class Base
      attr_reader :options, :config

      def initialize(options = nil, configuration: Lagoon.configuration.dup, **keyword_options)
        @config = configuration
        raw_options = (options || {}).to_h.merge(keyword_options)
        @options = Options.for(diagram_kind, raw_options, config: @config)
      end

      def generate
        parsed_data = parser.parse
        content = renderer.render(parsed_data)
        path = write_to_file(content)
        Result.new(
          path: path,
          content: content,
          warnings: parsed_data.fetch(:warnings, []),
          counts: parsed_data.fetch(:counts, infer_counts(parsed_data))
        )
      end

      protected

      def output_path
        @output_path ||= @options[:output] || File.join(@config.output_dir, default_filename)
      end

      def diagram_kind
        raise NotImplementedError, 'Subclasses must implement #diagram_kind'
      end

      def parser
        raise NotImplementedError, 'Subclasses must implement #parser'
      end

      def renderer
        raise NotImplementedError, 'Subclasses must implement #renderer'
      end

      def default_filename
        raise NotImplementedError, 'Subclasses must implement #default_filename'
      end

      def ensure_output_directory
        FileUtils.mkdir_p(File.dirname(output_path))
      end

      def write_to_file(content)
        ensure_output_directory
        Tempfile.create(['.lagoon', '.tmp'], File.dirname(output_path)) do |file|
          file.write(content)
          file.flush
          file.fsync
          file.close
          File.rename(file.path, output_path)
        end
        output_path
      rescue SystemCallError => e
        raise OutputError, "Failed to write #{output_path}: #{e.message}"
      end

      def infer_counts(parsed_data)
        {
          classes: parsed_data.fetch(:classes, []).size,
          entities: parsed_data.fetch(:entities, []).size,
          relationships: parsed_data.fetch(:relationships, []).size
        }.reject { |_key, count| count.zero? }
      end
    end
  end
end
