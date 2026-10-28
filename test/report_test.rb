# frozen_string_literal: true

require_relative "test_helper"

module Repolho
  class ReportTest < Minitest::Test
    def test_report_is_a_container
      stats = { "value" => Stats.new }
      report = Report.new("report", {}, stats)

      assert_kind_of Container, report
      assert_equal "report", report.id
    end

    def test_report_can_hold_page
      stats = { "value" => Stats.new }
      report = Report.new("report", {}, stats)
      page = Page.new("page", {}, stats)
      report.containers << page
      report.page = page

      assert_equal page, report.containers.first
      assert_equal page, report.page
    end
  end
end
