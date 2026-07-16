# frozen_string_literal: true

require "spec_helper"
require_relative "../../../lib/lagoon/analyzer/active_record_analyzer"

RSpec.describe Lagoon::Analyzer::ActiveRecordAnalyzer do
  subject(:analyzer) { described_class.new }

  describe "#analyze_model" do
    let(:mock_model) do
      double("Model",
             name: "User",
             abstract_class?: false,
             table_exists?: true,
             columns: [
               double("Column", name: "id", type: :integer),
               double("Column", name: "name", type: :string),
               double("Column", name: "email", type: :string),
               double("Column", name: "created_at", type: :datetime)
             ])
    end

    it "extracts model metadata" do
      result = analyzer.analyze_model(mock_model)

      expect(result[:name]).to eq("User")
      expect(result[:abstract]).to be false
      expect(result[:attributes]).to be_an(Array)
    end

    it "extracts columns when table exists" do
      result = analyzer.analyze_model(mock_model)

      expect(result[:attributes].size).to eq(4)
      expect(result[:attributes].map { |a| a[:name] }).to include("id", "name", "email", "created_at")
    end

    it "hides magic fields only when hide_magic is true" do
      result = analyzer.analyze_model(mock_model, hide_magic: true)

      expect(result[:attributes].size).to eq(2)
      expect(result[:attributes].map { |a| a[:name] }).to contain_exactly("email", "name")
    end

    it "returns empty attributes when table doesn't exist" do
      no_table_model = double("Model",
                              name: "NoTable",
                              abstract_class?: false,
                              table_exists?: false)

      result = analyzer.analyze_model(no_table_model)

      expect(result[:attributes]).to be_empty
    end

    it "marks model as abstract when it is abstract" do
      abstract_model = double("AbstractModel",
                              name: "ApplicationRecord",
                              abstract_class?: true,
                              table_exists?: false)

      result = analyzer.analyze_model(abstract_model)

      expect(result[:abstract]).to be true
    end
  end

  describe "#extract_associations" do
    let(:mock_model) do
      double("Model", name: "User")
    end

    let(:belongs_to_assoc) do
      double("Association",
             macro: :belongs_to,
             name: "role",
             class_name: "Role",
             options: {})
    end

    let(:has_many_assoc) do
      double("Association",
             macro: :has_many,
             name: "posts",
             class_name: "Post",
             options: {})
    end

    let(:through_assoc) do
      double("Association",
             macro: :has_many,
             name: "comments",
             class_name: "Comment",
             options: { through: :posts })
    end

    it "extracts belongs_to association when show_belongs_to is true" do
      allow(mock_model).to receive(:reflect_on_all_associations).and_return([belongs_to_assoc])

      result = analyzer.extract_associations(mock_model, show_belongs_to: true)

      expect(result.size).to eq(1)
      expect(result.first[:type]).to eq(:association)
      expect(result.first[:label]).to eq("belongs_to role")
      expect(result.first[:source]).to eq("User")
      expect(result.first[:target]).to eq("Role")
    end

    it "skips belongs_to when show_belongs_to is false" do
      allow(mock_model).to receive(:reflect_on_all_associations).and_return([belongs_to_assoc])

      result = analyzer.extract_associations(mock_model, show_belongs_to: false)

      expect(result).to be_empty
    end

    it "extracts has_many association" do
      allow(mock_model).to receive(:reflect_on_all_associations).and_return([has_many_assoc])

      result = analyzer.extract_associations(mock_model)

      expect(result.size).to eq(1)
      expect(result.first[:label]).to eq("has_many posts")
      expect(result.first[:source_cardinality]).to eq("1")
      expect(result.first[:target_cardinality]).to eq("*")
    end

    it "skips through associations when hide_through is true" do
      allow(mock_model).to receive(:reflect_on_all_associations).and_return([through_assoc])

      result = analyzer.extract_associations(mock_model, hide_through: true)

      expect(result).to be_empty
    end

    it "includes through associations when hide_through is false" do
      allow(mock_model).to receive(:reflect_on_all_associations).and_return([through_assoc])

      result = analyzer.extract_associations(mock_model, hide_through: false)

      expect(result.size).to eq(1)
    end

    it "handles NameError for missing association class" do
      bad_assoc = double("Association",
                         macro: :has_many,
                         name: "bad",
                         options: {})
      allow(bad_assoc).to receive(:class_name).and_raise(NameError)
      allow(mock_model).to receive(:reflect_on_all_associations).and_return([bad_assoc])

      result = analyzer.extract_associations(mock_model)

      expect(result).to be_empty
    end
  end

  describe "#extract_inheritance" do
    let(:mock_active_record_base) { double("ActiveRecordBase", name: "ActiveRecord::Base") }

    before do
      stub_const("ActiveRecord::Base", mock_active_record_base)
    end

    it "extracts inheritance when superclass is not ActiveRecord::Base" do
      mock_superclass = double("Superclass", name: "ApplicationRecord", abstract_class?: false)
      mock_model = double("Model",
                          name: "User",
                          superclass: mock_superclass)
      allow(mock_superclass).to receive(:==).with(mock_active_record_base).and_return(false)

      result = analyzer.extract_inheritance(mock_model)

      expect(result.size).to eq(1)
      expect(result.first[:source]).to eq("ApplicationRecord")
      expect(result.first[:target]).to eq("User")
      expect(result.first[:type]).to eq(:inheritance)
    end

    it "returns empty array when superclass is ActiveRecord::Base" do
      mock_model = double("Model",
                          name: "User",
                          superclass: mock_active_record_base)

      result = analyzer.extract_inheritance(mock_model)

      expect(result).to be_empty
    end

    it "keeps inheritance through an abstract application base" do
      abstract_superclass = double("Superclass", name: "ApplicationRecord", abstract_class?: true)
      mock_model = double("Model",
                          name: "User",
                          superclass: abstract_superclass)
      allow(abstract_superclass).to receive(:==).with(mock_active_record_base).and_return(false)

      result = analyzer.extract_inheritance(mock_model)

      expect(result.first).to include(source: "ApplicationRecord", target: "User")
    end

    it "does not hide unexpected implementation errors" do
      mock_model = double("Model", name: "User")
      allow(mock_model).to receive(:superclass).and_raise(StandardError)

      expect { analyzer.extract_inheritance(mock_model) }.to raise_error(StandardError)
    end
  end
end
