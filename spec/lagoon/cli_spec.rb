# frozen_string_literal: true

RSpec.describe Lagoon::CLI do
  subject(:cli) { described_class.new }

  describe "#version" do
    it "displays version number" do
      expect { cli.version }.to output(/Lagoon version #{Lagoon::VERSION}/).to_stdout
    end
  end

  describe "class options" do
    it "has verbose option" do
      expect(described_class.class_options[:verbose]).not_to be_nil
    end

    it "has output option" do
      expect(described_class.class_options[:output]).not_to be_nil
    end

    it "has direction option" do
      expect(described_class.class_options[:direction]).not_to be_nil
    end

    it "has root option" do
      expect(described_class.class_options[:root]).not_to be_nil
    end
  end

  describe "models command options" do
    let(:models_command) { described_class.commands["models"] }

    it "has brief option" do
      expect(models_command.options[:brief]).not_to be_nil
    end

    it "has inheritance option" do
      expect(models_command.options[:inheritance]).not_to be_nil
    end

    it "has exclude option" do
      expect(models_command.options[:exclude]).not_to be_nil
    end

    it "has specify option" do
      expect(models_command.options[:specify]).not_to be_nil
    end

    it "has all_models option" do
      expect(models_command.options[:all_models]).not_to be_nil
    end

    it "has show_belongs_to option" do
      expect(models_command.options[:show_belongs_to]).not_to be_nil
    end

    it "has hide_through option" do
      expect(models_command.options[:hide_through]).not_to be_nil
    end
  end

  describe "controllers command options" do
    let(:controllers_command) { described_class.commands["controllers"] }

    it "has brief option" do
      expect(controllers_command.options[:brief]).not_to be_nil
    end

    it "has inheritance option" do
      expect(controllers_command.options[:inheritance]).not_to be_nil
    end

    it "has hide_public option" do
      expect(controllers_command.options[:hide_public]).not_to be_nil
    end

    it "has hide_protected option" do
      expect(controllers_command.options[:hide_protected]).not_to be_nil
    end

    it "has hide_private option" do
      expect(controllers_command.options[:hide_private]).not_to be_nil
    end
  end

  describe "er command options" do
    let(:er_command) { described_class.commands["er"] }

    it "has exclude option" do
      expect(er_command.options[:exclude]).not_to be_nil
    end

    it "has specify option" do
      expect(er_command.options[:specify]).not_to be_nil
    end
  end

  describe "all command options" do
    let(:all_command) { described_class.commands["all"] }

    it "has brief option" do
      expect(all_command.options[:brief]).not_to be_nil
    end
  end
end
