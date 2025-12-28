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
          abstract: false,
          attributes: [],
          methods: extract_methods(controller, options)
        }
      end

      # Extract inheritance relationship from a controller
      #
      # @param controller [Class] ActionController class
      # @return [Array<Hash>] Inheritance metadata (empty or single element)
      def extract_inheritance(controller)
        return [] if controller.superclass == ActionController::Base
        return [] unless controller.superclass.name

        [{
          source: controller.superclass.name,
          target: controller.name,
          type: :inheritance,
          label: nil
        }]
      rescue StandardError
        []
      end

      private

      def extract_methods(controller, options = {})
        methods = []

        # Public methods (action methods)
        unless options[:hide_public]
          public_methods = controller.action_methods.to_a
          methods.concat(public_methods.map { |m| { name: m, visibility: "+" } })
        end

        # Protected methods
        unless options[:hide_protected]
          protected_methods = controller.protected_instance_methods(false)
          methods.concat(protected_methods.map { |m| { name: m, visibility: "#" } })
        end

        # Private methods
        unless options[:hide_private]
          private_methods = controller.private_instance_methods(false)
          methods.concat(private_methods.map { |m| { name: m, visibility: "-" } })
        end

        methods
      end
    end
  end
end
