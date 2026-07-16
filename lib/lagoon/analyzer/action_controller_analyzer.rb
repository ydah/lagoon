# frozen_string_literal: true

module Lagoon
  module Analyzer
    # Analyzes ActionController classes to extract metadata
    # including methods and inheritance
    class ActionControllerAnalyzer
      # Analyze a single controller and return its metadata
      #
      # @param controller [Class] ActionController class
      # @param options [Hash] Analysis options
      # @return [Hash] Controller metadata
      def analyze_controller(controller, options = {})
        {
          name: controller.name,
          abstract: abstract_controller?(controller),
          attributes: [],
          methods: extract_methods(controller, options)
        }
      end

      # Extract inheritance relationship from a controller
      #
      # @param controller [Class] ActionController class
      # @return [Array<Hash>] Inheritance metadata (empty or single element)
      def extract_inheritance(controller, include_framework_base: false)
        return [] if controller.superclass == ActionController::Base && !include_framework_base
        return [] unless controller.superclass.name
        return [] if !include_framework_base && controller.superclass.name.start_with?("ActionController::")

        [{
          source: controller.superclass.name,
          target: controller.name,
          type: :inheritance,
          label: nil
        }]
      rescue NameError
        []
      end

      private

      def extract_methods(controller, options = {})
        methods = []

        # Public methods (action methods)
        unless options[:hide_public]
          declared_public = controller.public_instance_methods(false).map(&:to_s)
          public_methods = controller.action_methods.to_a.map(&:to_s) & declared_public
          methods.concat(public_methods.map { |m| { name: m, visibility: "+" } })
        end

        # Protected methods
        unless options[:hide_protected]
          protected_methods = controller.protected_instance_methods(false).map(&:to_s)
          methods.concat(protected_methods.map { |m| { name: m, visibility: "#" } })
        end

        # Private methods
        unless options[:hide_private]
          private_methods = controller.private_instance_methods(false).map(&:to_s)
          methods.concat(private_methods.map { |m| { name: m, visibility: "-" } })
        end

        methods.sort_by { |method| [method[:visibility], method[:name]] }
      end

      def abstract_controller?(controller)
        return controller.abstract? if controller.respond_to?(:abstract?)
        return controller.abstract_controller? if controller.respond_to?(:abstract_controller?)

        false
      end
    end
  end
end
