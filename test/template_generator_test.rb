# frozen_string_literal: true

require_relative "test_helper"

class TemplateGeneratorTest < Minitest::Test
  include TestHelpers

  def setup
    @base = <<~HTML
      <!DOCTYPE html>
      <html>
        <body>
          <table>
            <report>
              <report-page rows="40">
                <report-header>
                  <tr>
                    <!-- REPORT:HEADERS -->
                  </tr>
                </report-header>

                <!-- REPORT:ROW -->

                <report-footer>
                  <tr><td colspan="99">Footer</td></tr>
                </report-footer>
              </report-page>
            </report>
          </table>
        </body>
      </html>
    HTML
  end

  def test_generates_headers_and_row_from_array_of_hashes
    data = [{ "id" => 1, "name" => "Alice", "total" => 10.5 }]
    file = write_temp_template(@base)

    generator = Repolho::TemplateGenerator.new(file.path, data)
    result = generator.generate

    assert_includes result, "<th>Id</th>"
    assert_includes result, "<th>Name</th>"
    assert_includes result, "<th>Total</th>"
    assert_includes result, "<report-row>"
    assert_includes result, "<%= attr(:id) %>"
    assert_includes result, "<%= attr(:name) %>"
    assert_includes result, "<%= attr(:total) %>"
    refute_includes result, "<!-- REPORT:HEADERS -->"
    refute_includes result, "<!-- REPORT:ROW -->"
  ensure
    file.unlink
  end

  def test_uses_explicit_column_list
    file = write_temp_template(@base)
    generator = Repolho::TemplateGenerator.new(file.path, %w[id customer_name])
    result = generator.generate

    assert_includes result, "<th>Id</th>"
    assert_includes result, "<th>Customer name</th>"
    assert_includes result, "<%= attr(:customer_name) %>"
  ensure
    file.unlink
  end

  def test_custom_labels_override
    file = write_temp_template(@base)
    generator = Repolho::TemplateGenerator.new(
      file.path,
      %w[id total],
      labels: { "total" => "Total (R$)" }
    )
    result = generator.generate

    assert_includes result, "<th>Total (R$)</th>"
    assert_includes result, "<th>Id</th>"
  ensure
    file.unlink
  end

  def test_numeric_columns_use_number_helper
    file = write_temp_template(@base)
    generator = Repolho::TemplateGenerator.new(
      file.path,
      %w[id total],
      numeric: %w[total]
    )
    result = generator.generate

    assert_includes result, "<%= number_with_precision(attr(:total), precision: 2) %>"
    assert_includes result, "<%= attr(:id) %>"
  ensure
    file.unlink
  end

  def test_raises_when_page_missing
    bad = @base.gsub("<report-page rows=\"40\">", "").gsub("</report-page>", "")
    file = write_temp_template(bad)

    generator = Repolho::TemplateGenerator.new(file.path, %w[id])
    error = assert_raises(ArgumentError) { generator.generate }
    assert_match(/report-page/, error.message)
  ensure
    file.unlink
  end

  def test_raises_when_markers_missing
    bad = @base.gsub("<!-- REPORT:HEADERS -->", "").gsub("<!-- REPORT:ROW -->", "")
    file = write_temp_template(bad)

    generator = Repolho::TemplateGenerator.new(file.path, %w[id])
    error = assert_raises(ArgumentError) { generator.generate }
    assert_match(/REPORT:HEADERS/, error.message)
  ensure
    file.unlink
  end

  def test_write_creates_file
    file = write_temp_template(@base)
    output = Tempfile.new(["out", ".rep.erb"])
    output.close

    generator = Repolho::TemplateGenerator.new(file.path, %w[id name])
    generator.write(output.path)

    content = File.read(output.path)
    assert_includes content, "<report-row>"
    assert_includes content, "<%= attr(:name) %>"
  ensure
    file.unlink
    output.unlink
  end
end
