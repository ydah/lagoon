# frozen_string_literal: true

require "prism"
require "set"

module Lagoon
  module Analyzer
    class AstModelReferenceAnalyzer
      # Analyze a controller file and return model references per action
      #
      # @param file_path [String] Path to controller file
      # @param action_names [Array<String>] List of action method names
      # @return [Hash] { action_name => [model_names] }
      def analyze(file_path, action_names)
        source = File.read(file_path)
        result = Prism.parse(source)

        visitor = ActionMethodVisitor.new(action_names)
        result.value.accept(visitor)
        visitor.action_models
      end

      class ActionMethodVisitor < Prism::Visitor
        attr_reader :action_models

        def initialize(action_names)
          @action_names = Set.new(action_names.map(&:to_s))
          @action_models = Hash.new { |h, k| h[k] = Set.new }
          @current_action = nil
        end

        # Track when we enter an action method
        def visit_def_node(node)
          method_name = node.name.to_s

          if @action_names.include?(method_name)
            @current_action = method_name
            super # Visit children (method body)
            @current_action = nil
          else
            super
          end
        end

        # Detect: User.find, Post.where, etc.
        def visit_call_node(node)
          if @current_action
            model_name = extract_model_from_call(node)
            @action_models[@current_action] << model_name if model_name
          end
          super
        end

        private

        def extract_model_from_call(node)
          # Pattern 1: User.find (ConstantReadNode receiver)
          if node.receiver.is_a?(Prism::ConstantReadNode)
            constant_name = node.receiver.name.to_s
            return constant_name if likely_model?(constant_name)
          end

          # Pattern 2: @user.posts (InstanceVariableReadNode + association)
          if node.receiver.is_a?(Prism::InstanceVariableReadNode)
            association_name = node.name.to_s
            return association_name.classify if looks_like_association?(association_name)
          end

          # Pattern 3: current_user.posts (CallNode receiver where receiver is current_user)
          if node.receiver.is_a?(Prism::CallNode) && node.receiver.name == :current_user
            # First add User model from current_user
            @action_models[@current_action] << "User" if @current_action
            # Then check if the method called on current_user is an association
            association_name = node.name.to_s
            return association_name.classify if looks_like_association?(association_name)
          end

          # Pattern 4: current_user (helper method by itself)
          if node.receiver.nil? && node.name == :current_user
            return "User"
          end

          nil
        end

        def likely_model?(name)
          # Filter out non-model constants
          return false if name.start_with?("Application", "Abstract")
          return false if %w[Rails ActiveRecord ActionController DateTime Date Time JSON Hash Array String
                             Integer].include?(name)

          # Model names are typically singular, capitalized
          name.match?(/\A[A-Z][a-z]/)
        end

        def looks_like_association?(name)
          # posts, comments, etc. (plural) or post, user (singular)
          # Filter out common attribute methods and controller methods
          excluded_methods = %w[
            params session request response cookies headers
            id name email created_at updated_at deleted_at
            count size length first last
          ]
          name.match?(/\A[a-z_]+\z/) && !excluded_methods.include?(name)
        end
      end
    end
  end
end
