# frozen_string_literal: true

require 'tmpdir'

RSpec.describe Lagoon::CLI do
  let(:result) do
    Lagoon::Result.new(path: 'doc/diagram.mermaid', content: 'classDiagram', warnings: [], counts: {})
  end

  around do |example|
    Dir.mktmpdir do |root|
      FileUtils.mkdir_p(File.join(root, 'config'))
      File.write(File.join(root, 'config', 'environment.rb'), "# CLI test environment\n")
      @rails_root = root
      example.run
    end
  end

  describe '#version' do
    it 'displays version number' do
      expect { described_class.start(['version']) }
        .to output(/Lagoon version #{Lagoon::VERSION}/).to_stdout
    end
  end

  describe 'models' do
    it 'passes implemented model options without leaking --root' do
      expect(Lagoon).to receive(:generate_model_diagram).with(
        hash_including(
          brief: true,
          hide_magic: true,
          hide_types: true,
          exclude: ['Audit'],
          specify: ['User'],
          output: 'tmp/model.mermaid'
        )
      ).and_return(result)

      expect do
        described_class.start(
          ['models', '--brief', '--hide-magic', '--hide-types', '--exclude', 'Audit',
           '--specify', 'User', '--output', 'tmp/model.mermaid', '--root', @rails_root]
        )
      end.to output(/Model diagram generated/).to_stdout
    end
  end

  describe 'controllers' do
    it 'routes exclude and specify to controller options' do
      expect(Lagoon).to receive(:generate_controller_diagram).with(
        hash_including(exclude: ['AdminController'], specify: ['UsersController'], brief: true)
      ).and_return(result)

      expect do
        described_class.start(
          ['controllers', '--exclude', 'AdminController', '--specify', 'UsersController',
           '--brief', '--root', @rails_root]
        )
      end.to output(/Controller diagram generated/).to_stdout
    end
  end

  describe 'er' do
    it 'routes table filtering options' do
      expect(Lagoon).to receive(:generate_er_diagram).with(
        hash_including(exclude: ['audits'], specify: ['users'])
      ).and_return(result)

      expect do
        described_class.start(['er', '--exclude', 'audits', '--specify', 'users', '--root', @rails_root])
      end.to output(/ER diagram generated/).to_stdout
    end
  end

  describe 'all' do
    it 'treats output as a directory and passes brief through' do
      results = {
        models: result,
        controllers: result,
        er: result,
        controller_models: result
      }
      expect(Lagoon).to receive(:generate_all).with(
        hash_including(output: 'tmp/diagrams', brief: true, direction: 'LR')
      ).and_return(results)

      expect do
        described_class.start(
          ['all', '--output', 'tmp/diagrams', '--brief', '--direction', 'LR', '--root', @rails_root]
        )
      end.to output(/All diagrams generated/).to_stdout
    end
  end

  describe 'Rails environment loading' do
    it 'restores the working directory after generation' do
      original_directory = Dir.pwd

      Dir.mktmpdir do |root|
        FileUtils.mkdir_p(File.join(root, 'config'))
        File.write(File.join(root, 'config', 'environment.rb'), "# test environment\n")
        cli = described_class.new([], { root: root })

        cli.send(:with_rails_environment) do
          expect(File.realpath(Dir.pwd)).to eq(File.realpath(root))
        end
      end

      expect(Dir.pwd).to eq(original_directory)
    end

    it 'raises Thor::Error instead of exiting when the root is invalid' do
      cli = described_class.new([], { root: '/missing/rails/application' })

      expect { cli.send(:with_rails_environment) { nil } }
        .to raise_error(Thor::Error, /Rails application not found/)
    end
  end

  describe 'option declarations' do
    it 'only exposes direction on diagrams that support it' do
      expect(described_class.class_options).not_to have_key(:direction)
      expect(described_class.commands.fetch('models').options).to have_key(:direction)
      expect(described_class.commands.fetch('controllers').options).to have_key(:direction)
      expect(described_class.commands.fetch('er').options).not_to have_key(:direction)
    end
  end
end
