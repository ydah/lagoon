# frozen_string_literal: true

require 'thor'

module Lagoon
  class CLI < Thor
    class_option :verbose, type: :boolean, aliases: '-v', desc: 'Enable verbose output'
    class_option :output, type: :string, aliases: '-o', desc: 'Output file path'
    class_option :root, type: :string, aliases: '-r', desc: 'Application root path'
    class_option :strict, type: :boolean, desc: 'Stop on the first analysis error'

    desc 'models', 'Generate Mermaid model diagram'
    method_option :direction, type: :string, aliases: '-d', desc: 'Diagram direction (TB/BT/LR/RL)'
    method_option :brief, type: :boolean, aliases: '-b', desc: 'Compact diagram (no attributes/methods)'
    method_option :inheritance, type: :boolean, aliases: '-i', desc: 'Include inheritance relationships'
    method_option :exclude, type: :array, aliases: '-e', desc: 'Exclude specified models'
    method_option :specify, type: :array, aliases: '-s', desc: 'Only process specified models'
    method_option :all_models, type: :boolean, aliases: '-a', desc: 'Include models outside app/models'
    method_option :show_belongs_to, type: :boolean, desc: 'Show belongs_to associations'
    method_option :hide_through, type: :boolean, desc: 'Hide through associations'
    method_option :all_columns, type: :boolean, desc: 'Show all columns even when --hide-magic is set'
    method_option :hide_magic, type: :boolean, desc: 'Hide id and timestamp fields'
    method_option :hide_types, type: :boolean, desc: 'Hide attribute types'
    def models
      with_rails_environment do
        report_result('Model', Lagoon.generate_model_diagram(command_options(:model)))
      end
    end

    desc 'controllers', 'Generate Mermaid controller diagram'
    method_option :direction, type: :string, aliases: '-d', desc: 'Diagram direction (TB/BT/LR/RL)'
    method_option :brief, type: :boolean, aliases: '-b', desc: 'Compact diagram (no methods)'
    method_option :inheritance, type: :boolean, aliases: '-i', desc: 'Include inheritance relationships'
    method_option :exclude, type: :array, aliases: '-e', desc: 'Exclude specified controllers'
    method_option :specify, type: :array, aliases: '-s', desc: 'Only process specified controllers'
    method_option :all_controllers, type: :boolean, desc: 'Include controllers outside app/controllers'
    method_option :hide_public, type: :boolean, desc: 'Hide public methods'
    method_option :hide_protected, type: :boolean, desc: 'Hide protected methods'
    method_option :hide_private, type: :boolean, desc: 'Hide private methods'
    def controllers
      with_rails_environment do
        report_result('Controller', Lagoon.generate_controller_diagram(command_options(:controller)))
      end
    end

    desc 'er', 'Generate Mermaid ER diagram'
    method_option :exclude, type: :array, aliases: '-e', desc: 'Exclude specified tables'
    method_option :specify, type: :array, aliases: '-s', desc: 'Only process specified tables'
    def er
      with_rails_environment do
        report_result('ER', Lagoon.generate_er_diagram(command_options(:er)))
      end
    end

    desc 'controller_models', 'Generate controller-model dependency diagram'
    method_option :direction, type: :string, aliases: '-d', desc: 'Diagram direction (TB/BT/LR/RL)'
    method_option :exclude, type: :array, aliases: '-e', desc: 'Exclude specified controllers'
    method_option :specify, type: :array, aliases: '-s', desc: 'Only process specified controllers'
    method_option :all_controllers, type: :boolean, desc: 'Include controllers outside app/controllers'
    method_option :show_actions, type: :boolean, default: true, desc: 'Show action names in labels'
    def controller_models
      with_rails_environment do
        result = Lagoon.generate_controller_model_diagram(command_options(:controller_model))
        report_result('Controller-model', result)
      end
    end

    desc 'all', 'Generate all diagrams'
    method_option :direction, type: :string, aliases: '-d', desc: 'Class diagram direction (TB/BT/LR/RL)'
    method_option :brief, type: :boolean, aliases: '-b', desc: 'Compact class diagrams'
    def all
      with_rails_environment do
        results = Lagoon.generate_all(all_options)
        say 'All diagrams generated:', :green
        results.each do |name, result|
          say "  #{name}: #{result.path}", :green
          report_warnings(result)
        end
      end
    end

    desc 'version', 'Show version'
    def version
      say "Lagoon version #{Lagoon::VERSION}"
    end

    def self.exit_on_failure?
      true
    end

    no_commands do
      private

      def with_rails_environment
        rails_root = File.expand_path(options[:root] || Dir.pwd)
        environment_file = File.join(rails_root, 'config', 'environment.rb')
        unless File.file?(environment_file)
          raise Thor::Error,
                'Rails application not found. Run from a Rails root or pass --root.'
        end

        Dir.chdir(rails_root) do
          require environment_file
          yield
        end
      rescue Thor::Error
        raise
      rescue LoadError, StandardError => e
        message = "#{e.class}: #{e.message}"
        message += "\n#{e.backtrace.join("\n")}" if options[:verbose] && e.backtrace
        raise Thor::Error, message
      end

      def command_options(kind)
        raw_options.slice(*Options.allowed_keys(kind))
      end

      def all_options
        allowed = Options::KEYS.values.flatten.uniq
        raw_options.slice(*allowed)
      end

      def raw_options
        options.to_h.transform_keys(&:to_sym).reject do |key, value|
          key == :root || value.nil?
        end
      end

      def report_result(label, result)
        say "#{label} diagram generated: #{result.path}", :green
        report_warnings(result)
      end

      def report_warnings(result)
        return unless options[:verbose]

        result.warnings.each { |warning| say "  Warning: #{warning}", :yellow }
      end
    end
  end
end
