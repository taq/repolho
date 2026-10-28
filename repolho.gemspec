# frozen_string_literal: true

require_relative "lib/repolho/version"

Gem::Specification.new do |spec|
  spec.name          = "repolho"
  spec.version       = Repolho::VERSION
  spec.authors       = ["Eustáquio Rangel"]
  spec.email         = ["taq@eustaquiorangel.com"]

  spec.summary       = "Report generator for Ruby and Rails from .rep.erb templates"
  spec.description   = "Repolho generates HTML reports from .rep.erb templates with support for nested groupings, page breaks, headers/footers, and statistics (sum, avg, min, max). Works with ActiveRecord::Result, Relation, or arrays of hashes."
  spec.homepage      = "https://github.com/taq/repolho"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.files         = Dir["lib/**/*", "certs/**/*", "README.md", "LICENSE", "test/**/*"]
  spec.require_paths = ["lib"]

  spec.cert_chain  = ["certs/taq.pem"]
  spec.signing_key = File.expand_path("~/.gemcert/gem-private_key.pem") if $PROGRAM_NAME.end_with?("gem")

  spec.add_dependency "nokogiri", "~> 1.16"

  spec.add_development_dependency "minitest", "~> 5.20"
  spec.add_development_dependency "rake", "~> 13.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
end
