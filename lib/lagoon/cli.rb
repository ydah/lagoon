# frozen_string_literal: true

require "thor"

module Lagoon
  class CLI < Thor
    class_option :verbose, type: :boolean, aliases: "-v", desc: "Enable verbose output"
    class_option :output, type: :string, aliases: "-o", desc: "Output file path"
    class_option :direction, type: :string, aliases: "-d", desc: "Diagram direction (TB/BT/LR/RL)"
    class_option :root, type: :string, aliases: "-r", desc: "Application root path"

    desc "models", "Generate Mermaid model diagram"
    method_option :brief, type: :boolean, aliases: "-b", desc: "Compact diagram (no attributes/methods)"
    method_option :inheritance, type: :boolean, aliases: "-i", desc: "Include inheritance relationships"
    method_option :exclude, type: :array, aliases: "-e", desc: "Exclude specified models"
    method_option :specify, type: :array, aliases: "-s", desc: "Only process specified models"
    method_option :all_models, type: :boolean, aliases: "-a", desc: "Include all models"
    method_option :show_belongs_to, type: :boolean, desc: "Show belongs_to associations"
    method_option :hide_through, type: :boolean, desc: "Hide through associations"
    method_option :all_columns, type: :boolean, desc: "Show all columns"
    method_option :hide_magic, type: :boolean, desc: "Hide magic fields (id, timestamps)"
    method_option :hide_types, type: :boolean, desc: "Hide attribute types"
    def models
      load_rails_environment
      setup_configuration

      output_file = Lagoon.generate_model_diagram(build_options)
      say "Model diagram generated: #{output_file}", :green
    end

    desc "controllers", "Generate Mermaid controller diagram"
    method_option :brief, type: :boolean, aliases: "-b", desc: "Compact diagram (no attributes/methods)"
    method_option :inheritance, type: :boolean, aliases: "-i", desc: "Include inheritance relationships"
    method_option :exclude, type: :array, aliases: "-e", desc: "Exclude specified controllers"
    method_option :specify, type: :array, aliases: "-s", desc: "Only process specified controllers"
    method_option :hide_public, type: :boolean, desc: "Hide public methods"
    method_option :hide_protected, type: :boolean, desc: "Hide protected methods"
    method_option :hide_private, type: :boolean, desc: "Hide private methods"
    def controllers
      load_rails_environment
      setup_configuration

      output_file = Lagoon.generate_controller_diagram(build_options)
      say "Controller diagram generated: #{output_file}", :green
    end

    desc "er", "Generate Mermaid ER diagram"
    method_option :exclude, type: :array, aliases: "-e", desc: "Exclude specified tables"
    method_option :specify, type: :array, aliases: "-s", desc: "Only process specified tables"
    def er
      load_rails_environment
      setup_configuration

      output_file = Lagoon.generate_er_diagram(build_options)
      say "ER diagram generated: #{output_file}", :green
    end

    desc "all", "Generate all diagrams"
    method_option :brief, type: :boolean, aliases: "-b", desc: "Compact diagrams (no attributes/methods)"
    def all
      load_rails_environment
      setup_configuration

      results = Lagoon.generate_all(build_options)
      say "All diagrams generated:", :green
      say "  Models: #{results[:models]}", :green
      say "  Controllers: #{results[:controllers]}", :green
      say "  ER: #{results[:er]}", :green
    end

    desc "version", "Show version"
    def version
      say "Lagoon version #{Lagoon::VERSION}"
    end

    private

    def load_rails_environment
      rails_root = options[:root] || Dir.pwd

      unless File.exist?(File.join(rails_root, "config", "environment.rb"))
        say "Error: Rails application not found. Please run from Rails root or use --root option.", :red
        exit 1
      end

      Dir.chdir(rails_root)
      require File.expand_path("config/environment", rails_root)
    rescue LoadError => e
      say "Error loading Rails environment: #{e.message}", :red
      exit 1
    end

    def setup_configuration
      Lagoon.configure do |config|
        config.diagram_direction = options[:direction] if options[:direction]
        config.show_attributes = !options[:brief] if options.key?(:brief)
        config.show_methods = !options[:brief] if options.key?(:brief)
        config.include_inheritance = options[:inheritance] if options.key?(:inheritance)
        config.exclude_models = options[:exclude] if options[:exclude]
      end
    end

    def build_options
      opts = options.dup
      opts[:show_belongs_to] = true if opts[:show_belongs_to]
      opts[:hide_through] = true if opts[:hide_through]
      opts[:all_columns] = true if opts[:all_columns]
      opts[:hide_magic] = true if opts[:hide_magic]
      opts
    end
  end
end
