# frozen_string_literal: true

namespace :mermaid do
  desc 'Generate all Mermaid diagrams'
  task all: :environment do
    results = Lagoon.generate_all
    puts 'All diagrams generated:'
    puts "  Models: #{results[:models]}"
    puts "  Controllers: #{results[:controllers]}"
    puts "  ER: #{results[:er]}"
    puts "  Controller-Models: #{results[:controller_models]}"
  end

  desc 'Generate Mermaid model diagram'
  task models: :environment do
    output_file = Lagoon.generate_model_diagram
    puts "Model diagram generated: #{output_file}"
  end

  desc 'Generate Mermaid controller diagram'
  task controllers: :environment do
    output_file = Lagoon.generate_controller_diagram
    puts "Controller diagram generated: #{output_file}"
  end

  desc 'Generate Mermaid ER diagram'
  task er: :environment do
    output_file = Lagoon.generate_er_diagram
    puts "ER diagram generated: #{output_file}"
  end

  desc 'Generate controller-model relationship diagram'
  task controller_models: :environment do
    output_file = Lagoon.generate_controller_model_diagram
    puts "Controller-model diagram generated: #{output_file}"
  end

  desc 'Generate brief diagrams (no attributes/methods)'
  task brief: :environment do
    results = Lagoon.generate_all(brief: true)
    puts 'Brief diagrams generated:'
    puts "  Models: #{results[:models]}"
    puts "  Controllers: #{results[:controllers]}"
    puts "  ER: #{results[:er]}"
    puts "  Controller-Models: #{results[:controller_models]}"
  end
end
