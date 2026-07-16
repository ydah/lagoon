# frozen_string_literal: true

module Lagoon
  module Analyzer
    class MethodReferenceVisitor < Prism::Visitor
      def initialize(methods:, model_names:, associations:, helper_models:)
        super()
        @methods = methods
        @model_names = model_names.to_set(&:to_s)
        @associations = normalize_associations(associations)
        @helper_models = helper_models.to_h.transform_keys(&:to_s).transform_values(&:to_s)
      end

      def models_for(action, callbacks: [])
        @models = Set.new
        @instance_variables = {}
        @method_stack = []

        callbacks.each { |callback| analyze_method(callback.to_s) }
        analyze_method(action.to_s)
        @models
      end

      def visit_def_node(_node)
        # Nested method definitions have an independent scope.
      end

      def visit_constant_read_node(node)
        record_model(node.name.to_s)
      end

      def visit_constant_path_node(node)
        record_model(constant_path_name(node))
      end

      def visit_local_variable_write_node(node)
        node.value&.accept(self)
        @local_variables[node.name.to_s] = infer_value(node.value)
      end

      def visit_instance_variable_write_node(node)
        node.value&.accept(self)
        @instance_variables[node.name.to_s] = infer_value(node.value)
      end

      def visit_call_node(node)
        node.receiver&.accept(self)
        node.arguments&.accept(self)

        returned_models = infer_call(node)
        returned_models.each { |model| record_model(model) }
        visit_block(node.block, returned_models) if node.block
      end

      private

      def analyze_method(method_name)
        return Set.new if @method_stack.include?(method_name)

        method_node = @methods[method_name]
        return Set.new unless method_node

        previous_locals = @local_variables
        @local_variables = {}
        @method_stack << method_name
        begin
          method_node.body&.accept(self)
          infer_last_expression(method_node.body)
        ensure
          @method_stack.pop
          @local_variables = previous_locals
        end
      end

      def infer_last_expression(body)
        last_node = body.respond_to?(:body) ? body.body.last : body
        infer_value(last_node)
      end

      def infer_call(node)
        if node.receiver.nil?
          helper_model = @helper_models[node.name.to_s]
          return Set[helper_model] if known_model?(helper_model)
          return analyze_method(node.name.to_s) if no_arguments?(node)

          return Set.new
        end

        receiver_models = infer_value(node.receiver)
        association_models = receiver_models.filter_map do |model|
          @associations.dig(model, node.name.to_s)
        end.flatten.to_set

        association_models.empty? ? receiver_models : association_models
      end

      def infer_value(node)
        case node
        when Prism::ConstantReadNode
          known_set(node.name.to_s)
        when Prism::ConstantPathNode
          known_set(constant_path_name(node))
        when Prism::LocalVariableReadNode
          @local_variables.fetch(node.name.to_s, Set.new)
        when Prism::InstanceVariableReadNode
          @instance_variables.fetch(node.name.to_s, Set.new)
        when Prism::CallNode
          infer_call(node)
        else
          Set.new
        end
      end

      def visit_block(block, yielded_models)
        previous = {}
        block_parameter_names(block).each do |name|
          previous[name] = @local_variables[name]
          @local_variables[name] = yielded_models
        end
        block.body&.accept(self)
      ensure
        previous&.each do |name, value|
          value ? @local_variables[name] = value : @local_variables.delete(name)
        end
      end

      def block_parameter_names(block)
        parameters = block.parameters&.parameters
        return [] unless parameters

        parameters.requireds.map { |parameter| parameter.name.to_s }
      end

      def no_arguments?(node)
        node.arguments.nil? || node.arguments.arguments.empty?
      end

      def record_model(name)
        @models << name if known_model?(name)
      end

      def known_set(name)
        known_model?(name) ? Set[name] : Set.new
      end

      def known_model?(name)
        name && @model_names.include?(name)
      end

      def normalize_associations(associations)
        associations.to_h.each_with_object({}) do |(model, mapping), result|
          result[model.to_s] = mapping.to_h.each_with_object({}) do |(name, targets), model_result|
            model_result[name.to_s] = Array(targets).map(&:to_s)
          end
        end
      end

      def constant_path_name(node)
        case node
        when Prism::ConstantReadNode
          node.name.to_s
        when Prism::ConstantPathNode
          [constant_path_name(node.parent), node.name.to_s].reject(&:empty?).join('::')
        else
          ''
        end
      end
    end
  end
end
