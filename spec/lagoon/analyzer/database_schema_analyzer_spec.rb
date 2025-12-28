# frozen_string_literal: true

require "spec_helper"
require_relative "../../../lib/lagoon/analyzer/database_schema_analyzer"

RSpec.describe Lagoon::Analyzer::DatabaseSchemaAnalyzer do
  subject(:analyzer) { described_class.new }

  describe "#analyze_table" do
    let(:columns) do
      [
        double("Column", name: "id", type: :integer),
        double("Column", name: "name", type: :string),
        double("Column", name: "email", type: :string),
        double("Column", name: "user_id", type: :integer),
        double("Column", name: "created_at", type: :datetime)
      ]
    end

    it "extracts table metadata" do
      result = analyzer.analyze_table("users", columns)

      expect(result[:name]).to eq("users")
      expect(result[:attributes]).to be_an(Array)
      expect(result[:attributes].size).to eq(5)
    end

    it "extracts column metadata" do
      result = analyzer.analyze_table("users", columns)

      name_col = result[:attributes].find { |a| a[:name] == "name" }
      expect(name_col[:type]).to eq(:string)
      expect(name_col[:primary_key]).to be false
      expect(name_col[:foreign_key]).to be false
    end

    it "marks id column as primary key" do
      result = analyzer.analyze_table("users", columns)

      id_col = result[:attributes].find { |a| a[:name] == "id" }
      expect(id_col[:primary_key]).to be true
    end

    it "marks _id columns as foreign keys" do
      result = analyzer.analyze_table("posts", columns)

      user_id_col = result[:attributes].find { |a| a[:name] == "user_id" }
      expect(user_id_col[:foreign_key]).to be true
    end
  end

  describe "#analyze_column" do
    it "extracts column metadata" do
      column = double("Column", name: "email", type: :string)

      result = analyzer.analyze_column(column)

      expect(result[:name]).to eq("email")
      expect(result[:type]).to eq(:string)
      expect(result[:primary_key]).to be false
      expect(result[:foreign_key]).to be false
      expect(result[:unique]).to be false
    end

    it "identifies primary key column" do
      column = double("Column", name: "id", type: :integer)

      result = analyzer.analyze_column(column)

      expect(result[:primary_key]).to be true
    end

    it "identifies foreign key column" do
      column = double("Column", name: "user_id", type: :integer)

      result = analyzer.analyze_column(column)

      expect(result[:foreign_key]).to be true
    end
  end

  describe "#extract_foreign_keys" do
    let(:columns) do
      [
        double("Column", name: "id", type: :integer),
        double("Column", name: "user_id", type: :integer),
        double("Column", name: "category_id", type: :integer),
        double("Column", name: "name", type: :string)
      ]
    end

    it "extracts foreign key relationships" do
      result = analyzer.extract_foreign_keys("posts", columns)

      expect(result.size).to eq(2)
    end

    it "infers target table from foreign key name" do
      result = analyzer.extract_foreign_keys("posts", columns)

      user_rel = result.find { |r| r[:target] == "users" }
      expect(user_rel).not_to be_nil
      expect(user_rel[:source]).to eq("posts")
      expect(user_rel[:label]).to eq("has many")
    end

    it "sets correct cardinality" do
      result = analyzer.extract_foreign_keys("posts", columns)

      rel = result.first
      expect(rel[:source_cardinality]).to eq("||")
      expect(rel[:target_cardinality]).to eq("}o")
      expect(rel[:identifying]).to be true
    end

    it "returns empty array when no foreign keys" do
      simple_columns = [
        double("Column", name: "id", type: :integer),
        double("Column", name: "name", type: :string)
      ]

      result = analyzer.extract_foreign_keys("users", simple_columns)

      expect(result).to be_empty
    end
  end

  describe "#internal_table?" do
    it "identifies schema_migrations as internal" do
      expect(analyzer.internal_table?("schema_migrations")).to be true
    end

    it "identifies ar_internal_metadata as internal" do
      expect(analyzer.internal_table?("ar_internal_metadata")).to be true
    end

    it "returns false for user tables" do
      expect(analyzer.internal_table?("users")).to be false
      expect(analyzer.internal_table?("posts")).to be false
    end
  end
end
