# frozen_string_literal: true

require 'prism'
require_relative 'ast/controller_scope_collector'
require_relative 'ast/method_reference_visitor'

module Lagoon
  module Analyzer
    class AstModelReferenceAnalyzer
      def analyze(file_paths, action_names, controller_names: nil, model_names: [], associations: {},
                  helper_models: {}, callback_methods: [])
        collector = ControllerScopeCollector.new(controller_names: controller_names)
        Array(file_paths).uniq.each do |file_path|
          parse_file(file_path).accept(collector)
        end

        visitor = MethodReferenceVisitor.new(
          methods: collector.methods,
          model_names: model_names,
          associations: associations,
          helper_models: helper_models
        )

        action_names.each_with_object({}) do |action_name, result|
          action = action_name.to_s
          next unless collector.methods.key?(action)

          callbacks = collector.callbacks_for(action) | callback_methods.map(&:to_s)
          result[action] = visitor.models_for(action, callbacks: callbacks)
        end
      end

      private

      def parse_file(file_path)
        result = Prism.parse_file(file_path)
        return result.value if result.success?

        details = result.errors.map(&:message).uniq.join('; ')
        raise ParseError, "Syntax error in #{file_path}: #{details}"
      end
    end
  end
end
