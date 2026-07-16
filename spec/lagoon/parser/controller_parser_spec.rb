# frozen_string_literal: true

RSpec.describe Lagoon::Parser::ControllerParser do
  let(:controller) { double('Controller', name: 'UsersController') }

  it 'supports controller-specific exclude and specify options' do
    parser = described_class.new(
      all_controllers: true,
      exclude: ['AdminController'],
      specify: %w[UsersController AdminController]
    )

    expect(parser.send(:excluded?, controller)).to be false
    expect(parser.send(:excluded?, double('Admin', name: 'AdminController'))).to be true
    expect(parser.send(:excluded?, double('Other', name: 'OtherController'))).to be true
    expect(parser.send(:excluded?, double('Anonymous', name: nil))).to be true
  end

  it 'turns brief into hidden public, protected, and private methods' do
    parser = described_class.new(all_controllers: true, brief: true)
    analyzer = instance_double(Lagoon::Analyzer::ActionControllerAnalyzer)
    allow(parser).to receive(:load_controllers).and_return([controller])
    parser.instance_variable_set(:@analyzer, analyzer)
    allow(analyzer).to receive(:extract_inheritance).and_return([])

    expect(analyzer).to receive(:analyze_controller).with(
      controller,
      hash_including(hide_public: true, hide_protected: true, hide_private: true)
    ).and_return(name: 'UsersController', abstract: false, attributes: [], methods: [])

    parser.parse
  end
end
