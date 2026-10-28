# frozen_string_literal: true

require_relative "test_helper"

module Repolho
  class MainTest < Minitest::Test
    include TestHelpers

    SIMPLE_TEMPLATE = <<~HTML
      <!DOCTYPE html>
      <html>
        <head><title>Test</title></head>
        <body>
          <table>
            <report>
              <report-header>
                <tr><th>Report Header <%= @company %></th></tr>
              </report-header>
              <report-page rows="5">
                <report-header>
                  <tr><th>Id</th><th>Value</th></tr>
                </report-header>
                <report-footer>
                  <tr><td>Page total</td><td><%= sum(:value) %></td></tr>
                </report-footer>
                <report-row>
                  <tr>
                    <td><%= attr(:id) %></td>
                    <td><%= attr(:value) %></td>
                  </tr>
                </report-row>
              </report-page>
              <report-footer>
                <tr><td>Grand total</td><td><%= sum(:value) %></td></tr>
              </report-footer>
            </report>
          </table>
        </body>
      </html>
    HTML

    GROUP_TEMPLATE = <<~HTML
      <!DOCTYPE html>
      <html>
        <body>
          <table>
            <report>
              <report-page rows="10">
                <report-header>
                  <tr><th>Name</th><th>Value</th></tr>
                </report-header>
                <report-group id="state" attr="state">
                  <report-header>
                    <tr><td colspan="2">State: <%= attr(:state) %></td></tr>
                  </report-header>
                  <report-footer>
                    <tr><td>State total</td><td><%= sum(:value) %></td></tr>
                  </report-footer>
                  <report-row>
                    <tr>
                      <td><%= attr(:name) %></td>
                      <td><%= attr(:value) %></td>
                    </tr>
                  </report-row>
                </report-group>
              </report-page>
            </report>
          </table>
        </body>
      </html>
    HTML

    def setup
      @data = [
        { "id" => 1, "name" => "Alice", "value" => 10.0, "state" => "SP" },
        { "id" => 2, "name" => "Bob",   "value" => 20.0, "state" => "SP" },
        { "id" => 3, "name" => "Carol", "value" => 15.0, "state" => "RJ" }
      ]
    end

    def test_normalize_data_array_of_hashes
      main = Main.new("/dev/null", @data)
      normalized = main.send(:normalize_data, @data)

      assert_equal 3, normalized.size
      assert_equal "Alice", normalized[0]["name"]
      assert_kind_of String, normalized[0].keys.first
    end

    def test_normalize_data_empty
      main = Main.new("/dev/null", [])
      assert_empty main.send(:normalize_data, [])
      assert_empty main.send(:normalize_data, nil)
    end

    def test_normalize_data_active_record_result_like
      result = Object.new
      rows = [{ "id" => 1, "value" => 100 }]
      result.define_singleton_method(:columns) { %w[id value] }
      result.define_singleton_method(:each) { |&b| rows.each(&b) }
      result.define_singleton_method(:map) { |&b| rows.map(&b) }

      main = Main.new("/dev/null", result)
      normalized = main.send(:normalize_data, result)

      assert_equal 1, normalized.size
      assert_equal 100, normalized[0]["value"]
    end

    def test_normalize_data_models_with_attributes
      model = Object.new
      model.define_singleton_method(:attributes) { { "id" => 5, "name" => "X" } }

      main = Main.new("/dev/null", [model])
      normalized = main.send(:normalize_data, [model])

      assert_equal "X", normalized[0]["name"]
    end

    def test_extract_sections
      template = write_temp_template(SIMPLE_TEMPLATE)
      main = Main.new(template.path, @data, { company: "Acme" })
      main.send(:parse)

      assert_includes main.instance_variable_get(:@previous), "<!DOCTYPE html>"
      assert_includes main.instance_variable_get(:@body), "<body>"
      assert_includes main.instance_variable_get(:@report_xml), "<report>"
      assert_includes main.instance_variable_get(:@after), "</html>"
    ensure
      template&.unlink
    end

    def test_simple_report_html_structure
      # Use higher row limit so headers/footers + 3 data rows fit in one page
      template_content = SIMPLE_TEMPLATE.gsub('rows="5"', 'rows="20"')
      template = write_temp_template(template_content)
      main = Main.new(template.path, @data, { company: "Acme" })
      main.run
      html = main.content.join
      doc = html_doc(html)

      assert_includes html, "Acme"
      assert_equal 1, page_tbodies(doc).size
      assert_includes html, "1"
      assert_includes html, "10"
      assert_includes html, "Grand total"
      # 10+20+15 = 45
      assert_includes html, "45"
    ensure
      template&.unlink
    end

    def test_group_breaks_on_attribute_change
      template = write_temp_template(GROUP_TEMPLATE)
      main = Main.new(template.path, @data)
      main.run
      html = main.content.join

      assert_includes html, "State: SP"
      assert_includes html, "State: RJ"
      # SP total 30, RJ total 15
      assert_includes html, "30"
      assert_includes html, "15"
    ensure
      template&.unlink
    end

    def test_page_break_with_small_row_limit
      small_page = SIMPLE_TEMPLATE.gsub('rows="5"', 'rows="2"')
      template = write_temp_template(small_page)
      main = Main.new(template.path, @data, { company: "Test" })
      main.run
      html = main.content.join
      doc = html_doc(html)

      pages = page_tbodies(doc)
      assert pages.size >= 2, "Expected multiple pages, got #{pages.size}"
      assert_includes html, 'data-page="1"'
      assert_includes html, 'data-page="2"'
    ensure
      template&.unlink
    end

    def test_pagination_enabled_when_multiple_pages
      paginated = SIMPLE_TEMPLATE.gsub("<report>", '<report pagination="true">').gsub('rows="5"', 'rows="2"')
      template = write_temp_template(paginated)
      main = Main.new(template.path, @data)
      main.run
      html = main.content.join

      assert_includes html, 'id="report-pagination"'
      assert_includes html, "change_report_page"
      assert_includes html, "First"
    ensure
      template&.unlink
    end

    def test_pagination_omitted_for_single_page
      # High row limit guarantees a single page even with headers/footers
      paginated = SIMPLE_TEMPLATE.gsub("<report>", '<report pagination="true">').gsub('rows="5"', 'rows="50"')
      template = write_temp_template(paginated)
      main = Main.new(template.path, @data)
      main.run
      html = main.content.join

      refute_includes html, 'id="report-pagination"'
    ensure
      template&.unlink
    end

    def test_custom_pagination_labels
      paginated = <<~HTML
        <!DOCTYPE html>
        <html><body>
          <table>
            <report pagination="true" pagination-first="Primeira" pagination-last="Última" pagination-prev="«" pagination-next="»">
              <report-page rows="2">
                <report-row><tr><td><%= attr(:id) %></td></tr></report-row>
              </report-page>
            </report>
          </table>
        </body></html>
      HTML
      template = write_temp_template(paginated)
      main = Main.new(template.path, @data)
      main.run
      html = main.content.join

      assert_includes html, "Primeira"
      assert_includes html, "Última"
      assert_includes html, "«"
    ensure
      template&.unlink
    end

    def test_orientation_and_paper_inject_print_css
      oriented = SIMPLE_TEMPLATE.gsub("<report>", '<report orientation="landscape" paper="A4">')
      template = write_temp_template(oriented)
      main = Main.new(template.path, @data)
      main.run
      html = main.content.join

      assert_includes html, "@media print"
      assert_includes html, "size: A4 landscape"
    ensure
      template&.unlink
    end

    def test_previous_and_after_are_rendered
      # previous (before <body>) and after (after </report>) are ERB-processed.
      # Content between <body> and <report> is stored in @body and inserted raw.
      template_content = <<~HTML
        <!DOCTYPE html>
        <html>
          <head><title><%= @title %></title></head>
          <body>
            <p>Before raw</p>
            <table>
              <report>
                <report-page rows="10">
                  <report-row><tr><td><%= attr(:id) %></td></tr></report-row>
                </report-page>
              </report>
            </table>
            <p>After <%= @company %></p>
          </body>
        </html>
      HTML
      template = write_temp_template(template_content)
      main = Main.new(template.path, @data, { title: "My Report", company: "Acme" })
      main.run
      html = main.content.join

      assert_includes html, "My Report"
      assert_includes html, "Before raw"
      assert_includes html, "After Acme"
    ensure
      template&.unlink
    end

    def test_reprint_header_on_page_break_attribute
      reprint = GROUP_TEMPLATE.gsub(
        '<report-group id="state" attr="state">',
        '<report-group id="state" attr="state" reprint-header-on-page-break="true">'
      )
      template = write_temp_template(reprint)
      main = Main.new(template.path, @data)
      main.send(:parse)

      groups = main.instance_variable_get(:@report).containers
      # The page has the group as container
      group = groups.first.containers.first
      assert group.reprint_header_on_page_break
    ensure
      template&.unlink
    end

    def test_group_header_reprinted_on_page_break
      # Force a page break in the middle of the same group
      data = [
        { "id" => 1, "name" => "Alice", "value" => 10.0, "state" => "SP" },
        { "id" => 2, "name" => "Bob",   "value" => 20.0, "state" => "SP" },
        { "id" => 3, "name" => "Carol", "value" => 15.0, "state" => "SP" },
        { "id" => 4, "name" => "Dave",  "value" => 25.0, "state" => "SP" },
        { "id" => 5, "name" => "Eve",   "value" => 30.0, "state" => "SP" }
      ]

      template_content = GROUP_TEMPLATE.gsub(
        '<report-page rows="10">',
        '<report-page rows="3">'
      ).gsub(
        '<report-group id="state" attr="state">',
        '<report-group id="state" attr="state" reprint-header-on-page-break="true">'
      )

      template = write_temp_template(template_content)
      main = Main.new(template.path, data)
      main.run
      html = main.content.join
      doc = html_doc(html)

      pages = page_tbodies(doc)
      assert pages.size >= 2, "Expected page break, got #{pages.size} page(s)"

      # Group header should appear more than once because of reprint
      header_count = html.scan(/State: SP/).size
      assert header_count >= 2, "Expected group header to be reprinted, found #{header_count} time(s)"
    ensure
      template&.unlink
    end

    def test_page_break_across_groups
      # Page break happens while groups are changing
      data = [
        { "id" => 1, "name" => "Alice", "value" => 10.0, "state" => "SP" },
        { "id" => 2, "name" => "Bob",   "value" => 20.0, "state" => "SP" },
        { "id" => 3, "name" => "Carol", "value" => 15.0, "state" => "RJ" },
        { "id" => 4, "name" => "Dave",  "value" => 25.0, "state" => "RJ" },
        { "id" => 5, "name" => "Eve",   "value" => 30.0, "state" => "MG" }
      ]

      template_content = GROUP_TEMPLATE.gsub(
        '<report-page rows="10">',
        '<report-page rows="2">'
      )

      template = write_temp_template(template_content)
      main = Main.new(template.path, data)
      main.run
      html = main.content.join
      doc = html_doc(html)

      pages = page_tbodies(doc)
      assert pages.size >= 2

      assert_includes html, "State: SP"
      assert_includes html, "State: RJ"
      assert_includes html, "State: MG"
    ensure
      template&.unlink
    end

    def test_make_columns_detects_numeric
      main = Main.new("/dev/null", @data)
      columns = main.send(:make_columns)

      assert_includes columns, "id"
      assert_includes columns, "value"
      refute_includes columns, "name"
      refute_includes columns, "state"
    end

    def test_page_number_available_in_after_erb
      after_erb = <<~HTML
        <!DOCTYPE html>
        <html><body>
          <table>
            <report>
              <report-page rows="2">
                <report-row><tr><td><%= attr(:id) %></td></tr></report-row>
              </report-page>
            </report>
          </table>
          <p>Total pages: <%= page_number %></p>
        </body></html>
      HTML
      template = write_temp_template(after_erb)
      main = Main.new(template.path, @data)
      main.run
      html = main.content.join

      assert_match(/Total pages: \d+/, html)
    ensure
      template&.unlink
    end
  end
end
