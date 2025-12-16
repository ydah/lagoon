# frozen_string_literal: true

RSpec.describe Lagoon do
  it "has a version number" do
    expect(Lagoon::VERSION).not_to be_nil
  end

  describe ".configuration" do
    it "returns a Configuration instance" do
      expect(described_class.configuration).to be_a(Lagoon::Configuration)
    end
  end

  describe ".configure" do
    it "yields the configuration" do
      expect { |b| described_class.configure(&b) }.to yield_with_args(Lagoon::Configuration)
    end

    it "allows setting configuration options" do
      described_class.configure do |config|
        config.output_dir = "custom/path"
      end

      expect(described_class.configuration.output_dir).to eq("custom/path")
    end
  end
end
