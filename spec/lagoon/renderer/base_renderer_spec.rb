# frozen_string_literal: true

RSpec.describe Lagoon::Renderer::BaseRenderer do
  subject(:renderer) { described_class.new(direction: "LR") }

  describe "#initialize" do
    it "sets direction" do
      expect(renderer.direction).to eq("LR")
    end

    it "defaults to TB direction" do
      renderer = described_class.new
      expect(renderer.direction).to eq("TB")
    end
  end

  describe "#render" do
    it "raises NotImplementedError" do
      expect { renderer.render({}) }.to raise_error(NotImplementedError, "Subclasses must implement #render")
    end
  end

  describe "#escape_class_name" do
    it "escapes class names with special characters" do
      escaped = renderer.send(:escape_class_name, "User::Profile")
      expect(escaped).to eq("`User::Profile`")
    end

    it "does not escape simple class names" do
      escaped = renderer.send(:escape_class_name, "User")
      expect(escaped).to eq("User")
    end

    it "does not escape names with underscores" do
      escaped = renderer.send(:escape_class_name, "User_Profile")
      expect(escaped).to eq("User_Profile")
    end
  end

  describe "#type_to_mermaid" do
    it "converts integer type" do
      expect(renderer.send(:type_to_mermaid, :integer)).to eq("Integer")
    end

    it "converts string type" do
      expect(renderer.send(:type_to_mermaid, :string)).to eq("String")
    end

    it "converts text type" do
      expect(renderer.send(:type_to_mermaid, :text)).to eq("Text")
    end

    it "converts boolean type" do
      expect(renderer.send(:type_to_mermaid, :boolean)).to eq("Boolean")
    end

    it "converts datetime type" do
      expect(renderer.send(:type_to_mermaid, :datetime)).to eq("DateTime")
    end

    it "converts date type" do
      expect(renderer.send(:type_to_mermaid, :date)).to eq("Date")
    end

    it "converts decimal type" do
      expect(renderer.send(:type_to_mermaid, :decimal)).to eq("Decimal")
    end

    it "converts float type" do
      expect(renderer.send(:type_to_mermaid, :float)).to eq("Float")
    end

    it "converts json type" do
      expect(renderer.send(:type_to_mermaid, :json)).to eq("JSON")
    end

    it "capitalizes unknown types" do
      expect(renderer.send(:type_to_mermaid, :custom)).to eq("Custom")
    end
  end
end
