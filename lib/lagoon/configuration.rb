# frozen_string_literal: true

module Lagoon
  class Configuration
    DIRECTIONS = %w[TB BT LR RL].freeze

    attr_accessor :show_attributes, :show_methods, :include_inheritance,
                  :exclude_models, :exclude_controllers, :exclude_tables,
                  :internal_tables, :include_framework_bases, :strict,
                  :helper_models
    attr_reader :output_dir, :diagram_direction

    def initialize
      self.output_dir = 'doc/diagrams'
      self.diagram_direction = 'TB'
      @show_attributes = true
      @show_methods = false
      @include_inheritance = true
      @exclude_models = []
      @exclude_controllers = []
      @exclude_tables = []
      @internal_tables = %w[schema_migrations ar_internal_metadata]
      @include_framework_bases = false
      @strict = false
      @helper_models = { 'current_user' => 'User' }
    end

    def output_dir=(value)
      path = value.to_s
      raise ConfigurationError, 'Output directory cannot be empty' if path.empty?

      @output_dir = path
    end

    def diagram_direction=(value)
      @diagram_direction = self.class.validate_direction!(value)
    end

    def self.validate_direction!(value)
      direction = value.to_s.upcase
      return direction if DIRECTIONS.include?(direction)

      raise ConfigurationError,
            "Invalid diagram direction #{value.inspect}; expected one of #{DIRECTIONS.join(', ')}"
    end

    def initialize_copy(original)
      super
      @exclude_models = original.exclude_models.dup
      @exclude_controllers = original.exclude_controllers.dup
      @exclude_tables = original.exclude_tables.dup
      @internal_tables = original.internal_tables.dup
      @helper_models = original.helper_models.dup
    end
  end
end
