# frozen_string_literal: true

require_relative "test_helper"

module Repolho
  class PageTest < Minitest::Test
    def setup
      @stats = { "value" => Stats.new }
      @page = Page.new("page", { title: "Report" }, @stats)
    end

    def test_default_rows
      assert_equal 60, @page.rows
      assert_equal 1, @page.row_number
      assert_equal 1, @page.page_number
    end

    def test_rows_setter_updates_valid_rows
      @page.rows = 20

      assert_equal 20, @page.rows
    end

    def test_append_raw_adds_content_without_counting
      @page.append_raw("<html><body>")

      assert_includes @page.content, "<html><body>"
      assert_equal 1, @page.row_number # unchanged
    end

    def test_shovel_counts_tr_and_opens_page
      @page << "<tr><td>one</td></tr><tr><td>two</td></tr>"

      assert_equal 3, @page.row_number # started at 1 + 2
      assert_equal 2, @page.content.size # open_page tag + content
      assert_includes @page.content.join, 'class="repolho-page"'
      assert_includes @page.content.join, 'data-page="1"'
    end

    def test_shovel_nil_is_ignored
      @page << nil

      assert_empty @page.content
    end

    def test_open_and_close_page
      @page.send(:open_page)
      assert_includes @page.content.join, 'data-page="1"'

      @page.send(:close_page)
      assert_includes @page.content.join, "</tbody>"
      assert_equal 2, @page.page_number
    end

    def test_finalize_closes_open_page
      @page << "<tr><td>x</td></tr>"
      @page.finalize

      assert_includes @page.content.join, "</tbody>"
    end

    def test_page_break_when_row_limit_reached
      @page.rows = 3
      @page.page = @page # required so << works inside check_page_break
      # Force row_number high enough
      @page.instance_variable_set(:@row_number, 3)
      @page.footer = { content: "<tr><td>footer</td></tr>" }

      @page.send(:check_page_break)

      assert_equal Container::FINISHED, @page.status
      assert_equal 0, @page.row_number
    end

    def test_content_is_array_of_strings
      @page.append_raw("before")
      @page << "<tr><td>row</td></tr>"
      @page.finalize

      assert_kind_of Array, @page.content
      assert @page.content.all? { |c| c.is_a?(String) }
    end
  end
end
