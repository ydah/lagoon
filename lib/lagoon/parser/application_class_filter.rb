# frozen_string_literal: true

require "active_support/core_ext/string/inflections"

module Lagoon
  module Parser
    class ApplicationClassFilter
      def initialize(directory:, include_all: false)
        @directory = directory
        @include_all = include_all
      end

      def include?(klass)
        return false unless klass.name
        return true if @include_all
        return true unless defined?(Rails) && Rails.respond_to?(:root)

        application_directory = File.expand_path(File.join(Rails.root.to_s, "app", @directory))
        source_locations(klass).any? do |location|
          File.expand_path(location).start_with?("#{application_directory}#{File::SEPARATOR}")
        end
      end

      private

      def source_locations(klass)
        locations = [constant_source_location(klass)]
        method_names = klass.instance_methods(false) +
                       klass.private_instance_methods(false) +
                       klass.protected_instance_methods(false)
        locations.concat(method_names.filter_map { |name| klass.instance_method(name).source_location&.first })
        locations.compact.uniq
      rescue NameError
        []
      end

      def constant_source_location(klass)
        namespace_name = klass.name.deconstantize
        constant_name = klass.name.demodulize.to_sym
        namespace = namespace_name.empty? ? Object : namespace_name.safe_constantize
        namespace&.const_source_location(constant_name)&.first
      end
    end
  end
end
