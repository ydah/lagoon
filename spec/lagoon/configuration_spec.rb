# frozen_string_literal: true

RSpec.describe Lagoon::Configuration do
  subject(:configuration) { described_class.new }

  describe "#initialize" do
    it "sets default output_dir" do
      expect(configuration.output_dir).to eq("doc/diagrams")
    end

    it "sets default diagram_direction" do
      expect(configuration.diagram_direction).to eq("TB")
    end

    it "sets default show_attributes" do
      expect(configuration.show_attributes).to be true
    end

    it "sets default show_methods" do
      expect(configuration.show_methods).to be false
    end

    it "sets default include_inheritance" do
      expect(configuration.include_inheritance).to be true
    end

    it "sets default exclude_models" do
      expect(configuration.exclude_models).to eq([])
    end

    it "sets default exclude_controllers" do
      expect(configuration.exclude_controllers).to eq([])
    end

    it "sets default diagram_format" do
      expect(configuration.diagram_format).to eq(:class_diagram)
    end
  end

  describe "attribute accessors" do
    it "allows setting output_dir" do
      configuration.output_dir = "custom/path"
      expect(configuration.output_dir).to eq("custom/path")
    end

    it "allows setting diagram_direction" do
      configuration.diagram_direction = "LR"
      expect(configuration.diagram_direction).to eq("LR")
    end

    it "allows setting show_attributes" do
      configuration.show_attributes = false
      expect(configuration.show_attributes).to be false
    end

    it "allows setting show_methods" do
      configuration.show_methods = true
      expect(configuration.show_methods).to be true
    end

    it "allows setting include_inheritance" do
      configuration.include_inheritance = false
      expect(configuration.include_inheritance).to be false
    end

    it "allows setting exclude_models" do
      configuration.exclude_models = ["User", "Post"]
      expect(configuration.exclude_models).to eq(["User", "Post"])
    end

    it "allows setting exclude_controllers" do
      configuration.exclude_controllers = ["ApplicationController"]
      expect(configuration.exclude_controllers).to eq(["ApplicationController"])
    end

    it "allows setting diagram_format" do
      configuration.diagram_format = :er_diagram
      expect(configuration.diagram_format).to eq(:er_diagram)
    end
  end
end
