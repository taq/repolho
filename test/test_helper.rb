# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "minitest/autorun"
require "repolho"
require "nokogiri"
require "tempfile"
require "stringio"

module TestHelpers
  def fixture_path(name)
    File.join(__dir__, "fixtures", name)
  end

  def write_temp_template(content)
    file = Tempfile.new(["report", ".rep.erb"])
    file.write(content)
    file.close
    file
  end

  def html_doc(html)
    Nokogiri::HTML(html)
  end

  def page_tbodies(doc)
    doc.css("tbody.repolho-page")
  end
end
