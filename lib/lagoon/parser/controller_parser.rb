# frozen_string_literal: true

module Lagoon
  module Parser
    class ControllerParser
      attr_reader :options, :config

      def initialize(options = {})
        @options = options
        @config = Lagoon.configuration
      end

      def parse
        controllers = load_controllers
        classes = []
        relationships = []

        controllers.each do |controller|
          next if excluded?(controller)

          classes << parse_controller(controller)
          relationships.concat(extract_inheritance(controller)) if config.include_inheritance
        end

        {
          classes: classes,
          relationships: relationships
        }
      end

      private

      def load_controllers
        # Railsアプリケーションの全コントローラをロード
        return [] unless defined?(Rails)

        Rails.application.eager_load!
        ActionController::Base.descendants
      end

      def excluded?(controller)
        controller_name = controller.name
        config.exclude_controllers.include?(controller_name)
      end

      def parse_controller(controller)
        {
          name: controller.name,
          abstract: false,
          attributes: [],
          methods: extract_methods(controller)
        }
      end

      def extract_methods(controller)
        methods = []

        # Public methods
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
    end
  end
end
