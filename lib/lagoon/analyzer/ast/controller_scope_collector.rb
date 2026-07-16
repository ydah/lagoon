# frozen_string_literal: true

module Lagoon
  module Analyzer
    class ControllerScopeCollector < Prism::Visitor
      Callback = Data.define(:method_name, :only_actions, :except_actions) do
        def applies_to?(action)
          return false if except_actions.include?(action)
          return true if only_actions.empty?

          only_actions.include?(action)
        end
      end

      attr_reader :methods

      def initialize(controller_names: nil)
        @controller_names = Array(controller_names).compact.map(&:to_s).to_set
        @methods = {}
        @callbacks = []
        @namespace = []
      end

      def callbacks_for(action)
        @callbacks.select { |callback| callback.applies_to?(action) }.map(&:method_name)
      end

      def visit_module_node(node)
        with_namespace(constant_path_name(node.constant_path)) { super }
      end

      def visit_class_node(node)
        class_name = qualified_name(node.constant_path)
        return unless @controller_names.empty? || @controller_names.include?(class_name)

        Array(node.body&.body).each do |child|
          case child
          when Prism::DefNode then @methods[child.name.to_s] = child
          when Prism::CallNode then collect_callback(child)
          end
        end
      end

      private

      def with_namespace(name)
        @namespace << name
        yield
      ensure
        @namespace.pop
      end

      def qualified_name(node)
        path = constant_path_name(node)
        return path if path.include?("::") || @namespace.empty?

        [*@namespace, path].join("::")
      end

      def constant_path_name(node)
        case node
        when Prism::ConstantReadNode
          node.name.to_s
        when Prism::ConstantPathNode
          [constant_path_name(node.parent), node.name.to_s].reject(&:empty?).join("::")
        else
          ""
        end
      end

      def collect_callback(node)
        return unless %i[before_action prepend_before_action append_before_action].include?(node.name)

        arguments = Array(node.arguments&.arguments)
        method_names = arguments.take_while { |argument| argument.is_a?(Prism::SymbolNode) }
                                .map(&:unescaped)
        options = callback_options(arguments.find { |argument| argument.is_a?(Prism::KeywordHashNode) })
        method_names.each do |method_name|
          @callbacks << Callback.new(
            method_name: method_name,
            only_actions: options.fetch("only", []),
            except_actions: options.fetch("except", [])
          )
        end
      end

      def callback_options(keyword_hash)
        return {} unless keyword_hash

        keyword_hash.elements.each_with_object({}) do |element, result|
          next unless element.is_a?(Prism::AssocNode) && element.key.is_a?(Prism::SymbolNode)

          result[element.key.unescaped] = symbol_values(element.value)
        end
      end

      def symbol_values(node)
        nodes = node.is_a?(Prism::ArrayNode) ? node.elements : [node]
        nodes.filter_map { |value| value.unescaped if value.is_a?(Prism::SymbolNode) }
      end
    end
  end
end
