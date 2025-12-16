# frozen_string_literal: true

RSpec.describe Lagoon::Diagram::Base do
  subject(:diagram) { described_class.new(options) }

  let(:options) { {} }

  before do
    allow(Lagoon).to receive(:configuration).and_return(
      instance_double(
        Lagoon::Configuration,
        output_dir: "spec/fixtures/output"
      )
    )
  end

  describe "#initialize" do
    it "sets options" do
      expect(diagram.options).to eq(options)
    end

    it "sets config from Lagoon.configuration" do
      expect(diagram.config).to respond_to(:output_dir)
    end
  end

  describe "#generate" do
    it "raises NotImplementedError" do
      expect { diagram.generate }.to raise_error(NotImplementedError, "Subclasses must implement #generate")
    end
  end

  describe "#default_filename" do
    it "raises NotImplementedError" do
      expect { diagram.send(:default_filename) }.to raise_error(NotImplementedError, "Subclasses must implement #default_filename")
    end
  end

  describe "#output_path" do
    it "combines output_dir and default_filename" do
      allow(diagram).to receive(:default_filename).and_return("test.mermaid")
      expect(diagram.send(:output_path)).to eq("spec/fixtures/output/test.mermaid")
    end
  end

  describe "#ensure_output_directory" do
    it "creates output directory if it doesn't exist" do
      allow(diagram).to receive(:default_filename).and_return("test.mermaid")
      allow(FileUtils).to receive(:mkdir_p)

      diagram.send(:ensure_output_directory)

      expect(FileUtils).to have_received(:mkdir_p).with("spec/fixtures/output")
    end
  end
end
