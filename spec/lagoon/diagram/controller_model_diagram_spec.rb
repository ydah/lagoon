# frozen_string_literal: true

require "spec_helper"
require "tempfile"
require "fileutils"
require_relative "../../../lib/lagoon/diagram/base"
require_relative "../../../lib/lagoon/analyzer/ast_model_reference_analyzer"
require_relative "../../../lib/lagoon/parser/controller_model_parser"
require_relative "../../../lib/lagoon/renderer/base_renderer"
require_relative "../../../lib/lagoon/renderer/controller_model_er_renderer"
require_relative "../../../lib/lagoon/diagram/controller_model_diagram"

RSpec.describe Lagoon::Diagram::ControllerModelDiagram do
  let(:diagram) { described_class.new }
  let(:temp_dir) { Dir.mktmpdir }

  after do
    FileUtils.rm_rf(temp_dir)
  end

  describe "#default_filename" do
    it "returns controller_models.mermaid" do
      expect(diagram.send(:default_filename)).to eq("controller_models.mermaid")
    end
  end

  describe "integration with parser and renderer" do
    it "generates diagram by coordinating parser and renderer" do
      # Mock parser
      mock_parser = instance_double(Lagoon::Parser::ControllerModelParser)
      parsed_data = {
        relationships: [
          { controller: "UsersController", model: "User", actions: ["index", "show"] }
        ]
      }
      allow(Lagoon::Parser::ControllerModelParser).to receive(:new).and_return(mock_parser)
      allow(mock_parser).to receive(:parse).and_return(parsed_data)

      # Execute with custom output directory
      output_file = File.join(temp_dir, "test_output.mermaid")
      diagram_with_output = described_class.new(output: output_file)

      result = diagram_with_output.generate

      expect(result.path).to eq(output_file)
      expect(File.exist?(output_file)).to be true

      content = File.read(output_file)
      expect(content).to include("classDiagram")
      expect(content).to include("UsersController ..> User")
    end
  end

  describe "options passing" do
    it "passes options to parser" do
      mock_parser = instance_double(Lagoon::Parser::ControllerModelParser)
      allow(mock_parser).to receive(:parse).and_return({ relationships: [] })

      expect(Lagoon::Parser::ControllerModelParser).to receive(:new) do |options|
        expect(options[:exclude]).to eq(["AdminController"])
        mock_parser
      end

      diagram_with_options = described_class.new(
        output: File.join(temp_dir, "output.mermaid"),
        exclude: ["AdminController"]
      )
      diagram_with_options.generate
    end

    it "passes show_actions option to renderer" do
      mock_parser = instance_double(Lagoon::Parser::ControllerModelParser)
      allow(Lagoon::Parser::ControllerModelParser).to receive(:new).and_return(mock_parser)
      allow(mock_parser).to receive(:parse).and_return({ relationships: [] })

      mock_renderer = instance_double(Lagoon::Renderer::ControllerModelErRenderer)
      allow(mock_renderer).to receive(:render).and_return("erDiagram")

      expect(Lagoon::Renderer::ControllerModelErRenderer).to receive(:new)
        .with(hash_including(show_actions: false))
        .and_return(mock_renderer)

      diagram_with_options = described_class.new(
        output: File.join(temp_dir, "output.mermaid"),
        show_actions: false
      )
      diagram_with_options.generate
    end

    it "passes direction option to renderer" do
      mock_parser = instance_double(Lagoon::Parser::ControllerModelParser)
      allow(Lagoon::Parser::ControllerModelParser).to receive(:new).and_return(mock_parser)
      allow(mock_parser).to receive(:parse).and_return({ relationships: [] })

      mock_renderer = instance_double(Lagoon::Renderer::ControllerModelErRenderer)
      allow(mock_renderer).to receive(:render).and_return("erDiagram")

      expect(Lagoon::Renderer::ControllerModelErRenderer).to receive(:new)
        .with(hash_including(direction: "LR"))
        .and_return(mock_renderer)

      diagram_with_options = described_class.new(
        output: File.join(temp_dir, "output.mermaid"),
        direction: "LR"
      )
      diagram_with_options.generate
    end
  end

  describe "file writing" do
    it "creates output directory if it doesn't exist" do
      nested_dir = File.join(temp_dir, "nested", "deep", "path")
      output_file = File.join(nested_dir, "diagram.mermaid")

      mock_parser = instance_double(Lagoon::Parser::ControllerModelParser)
      allow(Lagoon::Parser::ControllerModelParser).to receive(:new).and_return(mock_parser)
      allow(mock_parser).to receive(:parse).and_return({ relationships: [] })

      # Override config to use temp directory
      allow_any_instance_of(Lagoon::Configuration).to receive(:output_dir).and_return(nested_dir)

      diagram_with_nested_output = described_class.new(output: output_file)
      diagram_with_nested_output.generate

      expect(File.exist?(output_file)).to be true
      expect(File.directory?(nested_dir)).to be true
    end

    it "writes valid Mermaid content to file" do
      output_file = File.join(temp_dir, "controller_models.mermaid")

      mock_parser = instance_double(Lagoon::Parser::ControllerModelParser)
      parsed_data = {
        relationships: [
          { controller: "UsersController", model: "User", actions: ["index", "show"] },
          { controller: "PostsController", model: "Post", actions: ["index"] }
        ]
      }
      allow(Lagoon::Parser::ControllerModelParser).to receive(:new).and_return(mock_parser)
      allow(mock_parser).to receive(:parse).and_return(parsed_data)

      diagram_with_output = described_class.new(output: output_file)
      diagram_with_output.generate

      content = File.read(output_file)
      expect(content).to start_with("classDiagram")
      expect(content).to include("UsersController")
      expect(content).to include("PostsController")
      expect(content).to include("User")
      expect(content).to include("Post")
    end
  end

  describe "return value" do
    it "returns the output file path" do
      output_file = File.join(temp_dir, "test.mermaid")

      mock_parser = instance_double(Lagoon::Parser::ControllerModelParser)
      allow(Lagoon::Parser::ControllerModelParser).to receive(:new).and_return(mock_parser)
      allow(mock_parser).to receive(:parse).and_return({ relationships: [] })

      diagram_with_output = described_class.new(output: output_file)
      result = diagram_with_output.generate

      expect(result.path).to eq(output_file)
    end
  end
end
