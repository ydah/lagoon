# frozen_string_literal: true

module Lagoon
  class Railtie < Rails::Railtie
    railtie_name :lagoon

    rake_tasks do
      load "tasks/lagoon.rake"
    end
  end
end
