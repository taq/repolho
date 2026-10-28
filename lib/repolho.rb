# frozen_string_literal: true

require_relative "repolho/version"
require_relative "repolho/stats"
require_relative "repolho/container"
require_relative "repolho/page"
require_relative "repolho/report"
require_relative "repolho/main"

module Repolho
  # Includes Rails helper modules into Container so they become available
  # in ERB templates (headers, footers, rows, previous and after).
  #
  # By default includes ActionView::Helpers::NumberHelper.
  # Pass additional modules if needed.
  #
  # Example:
  #   Repolho.include_rails_helpers!
  #   Repolho.include_rails_helpers!(ActionView::Helpers::NumberHelper, ActionView::Helpers::TextHelper)
  def self.include_rails_helpers!(*modules)
    modules = [ActionView::Helpers::NumberHelper] if modules.empty?
    modules.each { |mod| Container.include(mod) }
  end
end
