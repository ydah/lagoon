# frozen_string_literal: true

require "spec_helper"
require_relative "../../../lib/lagoon/analyzer/action_controller_analyzer"

RSpec.describe Lagoon::Analyzer::ActionControllerAnalyzer do
  subject(:analyzer) { described_class.new }

  describe "#analyze_controller" do
    let(:mock_controller) do
      double("Controller",
             name: "UsersController",
             action_methods: %w[index show create update destroy].to_set,
             protected_instance_methods: [:authenticate, :set_user],
             private_instance_methods: [:user_params, :find_user])
    end

    it "extracts controller metadata" do
      result = analyzer.analyze_controller(mock_controller)

      expect(result[:name]).to eq("UsersController")
      expect(result[:abstract]).to be false
      expect(result[:attributes]).to be_empty
      expect(result[:methods]).to be_an(Array)
    end

    it "extracts public action methods" do
      result = analyzer.analyze_controller(mock_controller)

      public_methods = result[:methods].select { |m| m[:visibility] == "+" }
      expect(public_methods.size).to eq(5)
      expect(public_methods.map { |m| m[:name] }).to include("index", "show", "create")
    end

    it "extracts protected methods" do
      result = analyzer.analyze_controller(mock_controller)

      protected_methods = result[:methods].select { |m| m[:visibility] == "#" }
      expect(protected_methods.size).to eq(2)
      expect(protected_methods.map { |m| m[:name] }).to include(:authenticate, :set_user)
    end

    it "extracts private methods" do
      result = analyzer.analyze_controller(mock_controller)

      private_methods = result[:methods].select { |m| m[:visibility] == "-" }
      expect(private_methods.size).to eq(2)
      expect(private_methods.map { |m| m[:name] }).to include(:user_params, :find_user)
    end

    it "hides public methods when hide_public is true" do
      result = analyzer.analyze_controller(mock_controller, hide_public: true)

      public_methods = result[:methods].select { |m| m[:visibility] == "+" }
      expect(public_methods).to be_empty
    end

    it "hides protected methods when hide_protected is true" do
      result = analyzer.analyze_controller(mock_controller, hide_protected: true)

      protected_methods = result[:methods].select { |m| m[:visibility] == "#" }
      expect(protected_methods).to be_empty
    end

    it "hides private methods when hide_private is true" do
      result = analyzer.analyze_controller(mock_controller, hide_private: true)

      private_methods = result[:methods].select { |m| m[:visibility] == "-" }
      expect(private_methods).to be_empty
    end

    it "returns only public methods when hiding protected and private" do
      result = analyzer.analyze_controller(mock_controller,
                                           hide_protected: true,
                                           hide_private: true)

      expect(result[:methods].size).to eq(5)
      expect(result[:methods].all? { |m| m[:visibility] == "+" }).to be true
    end

    it "returns empty methods array when hiding all" do
      result = analyzer.analyze_controller(mock_controller,
                                           hide_public: true,
                                           hide_protected: true,
                                           hide_private: true)

      expect(result[:methods]).to be_empty
    end
  end

  describe "#extract_inheritance" do
    let(:mock_action_controller_base) { double("ActionControllerBase", name: "ActionController::Base") }

    before do
      stub_const("ActionController::Base", mock_action_controller_base)
    end

    it "extracts inheritance when superclass is not ActionController::Base" do
      mock_superclass = double("Superclass", name: "ApplicationController")
      mock_controller = double("Controller",
                               name: "UsersController",
                               superclass: mock_superclass)
      allow(mock_superclass).to receive(:==).with(mock_action_controller_base).and_return(false)

      result = analyzer.extract_inheritance(mock_controller)

      expect(result.size).to eq(1)
      expect(result.first[:source]).to eq("ApplicationController")
      expect(result.first[:target]).to eq("UsersController")
      expect(result.first[:type]).to eq(:inheritance)
      expect(result.first[:label]).to be_nil
    end

    it "returns empty array when superclass is ActionController::Base" do
      mock_controller = double("Controller",
                               name: "ApplicationController",
                               superclass: mock_action_controller_base)

      result = analyzer.extract_inheritance(mock_controller)

      expect(result).to be_empty
    end

    it "returns empty array when superclass has no name" do
      mock_superclass = double("Superclass", name: nil)
      mock_controller = double("Controller",
                               name: "UsersController",
                               superclass: mock_superclass)
      allow(mock_superclass).to receive(:==).with(mock_action_controller_base).and_return(false)

      result = analyzer.extract_inheritance(mock_controller)

      expect(result).to be_empty
    end

    it "handles errors gracefully" do
      mock_controller = double("Controller", name: "UsersController")
      allow(mock_controller).to receive(:superclass).and_raise(StandardError)

      result = analyzer.extract_inheritance(mock_controller)

      expect(result).to be_empty
    end
  end
end
