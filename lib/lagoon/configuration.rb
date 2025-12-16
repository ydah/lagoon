# frozen_string_literal: true

module Lagoon
  class Configuration
    attr_accessor :output_dir, :diagram_direction, :show_attributes,
                  :show_methods, :include_inheritance, :exclude_models,
                  :exclude_controllers, :diagram_format

    def initialize
      @output_dir = "doc/diagrams"
      @diagram_direction = "TB"
      @show_attributes = true
      @show_methods = false
      @include_inheritance = true
      @exclude_models = []
      @exclude_controllers = []
      @diagram_format = :class_diagram # or :er_diagram
    end
  end
end
