# frozen_string_literal: true

module Lagoon
  module Diagram
    class Base
      attr_reader :options, :config

      def initialize(options = {})
        @options = options
        @config = Lagoon.configuration
      end

      def generate
        raise NotImplementedError, "Subclasses must implement #generate"
      end

      protected

      def output_path
        @output_path ||= File.join(@config.output_dir, default_filename)
      end

      def default_filename
        raise NotImplementedError, "Subclasses must implement #default_filename"
      end

      def ensure_output_directory
        FileUtils.mkdir_p(@config.output_dir)
      end

      def write_to_file(content)
        ensure_output_directory
        File.write(output_path, content)
        output_path
      end
    end
  end
end
