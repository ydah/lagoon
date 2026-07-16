# frozen_string_literal: true

RSpec.describe Lagoon::Options do
  it 'normalizes brief model output' do
    options = described_class.for(:model, brief: true)

    expect(options[:show_attributes]).to be false
    expect(options[:show_methods]).to be false
  end

  it 'combines global and per-call exclusions without mutating configuration' do
    config = Lagoon::Configuration.new
    config.exclude_models = ['ApplicationRecord']

    options = described_class.for(:model, { exclude: ['Audit'] }, config: config)

    expect(options[:exclude]).to eq(%w[ApplicationRecord Audit])
    expect(config.exclude_models).to eq(['ApplicationRecord'])
  end

  it 'rejects unknown options' do
    expect { described_class.for(:er, typo: true) }
      .to raise_error(Lagoon::ConfigurationError, /Unknown er option.*typo/)
  end

  it 'normalizes configurable current helpers' do
    options = described_class.for(:controller_model, helper_models: { current_account: 'Account' })

    expect(options[:helper_models]).to eq('current_account' => 'Account')
  end
end
