# typed: false
# frozen_string_literal: true
require_relative "container"
require_relative "page"
require_relative "report"
require_relative "stats"
require "nokogiri"
require "erb"
require "cgi"

module Repolho
  class Main
    PAGINATION_TBODY = <<~HTML
      <tbody id="report-pagination" data-max="<%= page_number %>">
        <tr>
          <td colspan="200" id="report-pagination-links">
            <a href="#" id="report-first-page"><%= @pagination_first %></a>
            <a href="#" id="report-prev-page"><%= @pagination_prev %></a>
            <input type="number" id="report-current-page" min="1" max="<%= page_number %>" value="1"/>
            <a href="#" id="report-next-page"><%= @pagination_next %></a>
            <a href="#" id="report-last-page"><%= @pagination_last %></a>
          </td>
        </tr>
      </tbody>
    HTML

    PAGINATION_SCRIPT = <<~HTML
      <script>
        function change_report_page(page) {
          try {
            const pages = document.querySelectorAll(".repolho-page");
            page = parseInt(page, 10);
            if (isNaN(page) || page < 1) page = 1;
            if (page > pages.length) page = pages.length;

            pages.forEach(function(p) { p.style.display = "none"; });
            var target = document.querySelector('[data-page="' + page + '"]');
            if (target) target.style.display = "";

            var input = document.getElementById("report-current-page");
            if (input) input.value = page;
          } catch (e) {
            console.error("Repolho pagination error:", e);
          }
        }

        document.addEventListener("DOMContentLoaded", function() {
          try {
            var first = document.getElementById("report-first-page");
            var prev  = document.getElementById("report-prev-page");
            var next  = document.getElementById("report-next-page");
            var last  = document.getElementById("report-last-page");
            var input = document.getElementById("report-current-page");

            if (first) first.addEventListener("click", function(e) { e.preventDefault(); change_report_page(1); });
            if (prev)  prev.addEventListener("click",  function(e) { e.preventDefault(); change_report_page(parseInt(input && input.value || 1, 10) - 1); });
            if (next)  next.addEventListener("click",  function(e) { e.preventDefault(); change_report_page(parseInt(input && input.value || 1, 10) + 1); });
            if (last)  last.addEventListener("click",  function(e) { e.preventDefault(); change_report_page(9999); });
            if (input) input.addEventListener("change", function(e) { change_report_page(e.target.value); });

            change_report_page(1);
          } catch (e) {
            console.error("Repolho pagination init error:", e);
          }
        });
      </script>
    HTML

    def initialize(path, data, locals = {})
      @path        = path
      @data        = normalize_data(data)
      @locals      = locals
      @columns     = make_columns
      @page        = Page.new("page", locals, make_stats)
      @report      = Report.new("report", locals, make_stats)
      @previous    = ""
      @after       = ""
      @body        = ""
      @pagination  = false
      @orientation = nil
      @paper       = nil
      @last_page_template = nil
      @pagination_labels = {
        first: "First",
        prev:  "<",
        next:  ">",
        last:  "Last"
      }

      @report.containers << @page
      @report.page = @page
    end

    def content
      @page.content
    end

    def run
      parse

      @page.append_raw(render_erb(@previous))
      @page.append_raw(@body)

      @data.each do |row|
        @report.call(:row, row)
      end

      inject_last_page_content

      @report.call(:finish, nil)
      @page.finalize

      # After finalize, page_number is one past the last page.
      # Set it to the real total so ERB (pagination + @after) sees the correct value.
      total_pages = [@page.page_number - 1, 1].max
      @page.instance_variable_set(:@page_number, total_pages)

      after_content = render_erb(@after)

      if @pagination && total_pages > 1
        inject_pagination_labels
        @page.append_raw(render_erb(PAGINATION_TBODY))

        script = PAGINATION_SCRIPT
        if after_content =~ /<\/body>/i
          after_content = after_content.sub(/<\/body>/i, "#{script}</body>")
        else
          after_content += script
        end
      end

      css = print_css
      if css
        if after_content =~ /<\/body>/i
          after_content = after_content.sub(/<\/body>/i, "#{css}</body>")
        else
          after_content += css
        end
      end

      @page.append_raw(after_content)
    end

    private

    def inject_last_page_content
      return if @last_page_template.nil? || @last_page_template.strip.empty?

      @page.mark_as_last!
      rendered = render_erb(@last_page_template)
      @page.inject_as_rows(rendered)
      # Page footer is rendered later by the normal :finish path,
      # after any remaining group footers.
    end

    def inject_pagination_labels
      @page.instance_variable_set(:@pagination_first, @pagination_labels[:first])
      @page.instance_variable_set(:@pagination_prev,  @pagination_labels[:prev])
      @page.instance_variable_set(:@pagination_next,  @pagination_labels[:next])
      @page.instance_variable_set(:@pagination_last,  @pagination_labels[:last])
    end

    def print_css
      return nil unless @orientation || @paper

      size_parts = []
      size_parts << @paper if @paper
      size_parts << @orientation if @orientation
      size = size_parts.join(" ")

      <<~HTML
        <style>
          @media print {
            @page {
              size: #{size};
            }
          }
        </style>
      HTML
    end

    def make_columns
      return [] if @data.empty?

      sample = @data.first

      sample.keys.select do |col|
        val = sample[col]
        val.is_a?(Numeric) || (val.is_a?(String) && val.match?(/\A-?\d+(\.\d+)?\z/))
      end
    end

    def normalize_data(data)
      return [] if data.nil? || (data.respond_to?(:empty?) && data.empty?)

      # ActiveRecord::Result (exec_query)
      if data.respond_to?(:columns) && data.respond_to?(:each)
        return data.map { |row| row.to_h.transform_keys(&:to_s) }
      end

      # ActiveRecord::Relation, array of models, or any Enumerable of objects with attributes
      rows = data.respond_to?(:to_a) ? data.to_a : Array(data)
      return [] if rows.empty?

      first = rows.first
      if first.respond_to?(:attributes)
        return rows.map { |r| r.attributes.transform_keys(&:to_s) }
      end

      # Already an array of hashes
      if first.is_a?(Hash)
        return rows.map { |r| r.transform_keys(&:to_s) }
      end

      rows
    end

    def make_stats
      @columns.each_with_object({}) do |column, memo|
        memo[column] = Stats.new
      end
    end

    def parse
      content = File.read(@path)
      extract_sections(content)
      build_report_structure
    end

    def extract_sections(content)
      matches = content.gsub(/\n/, "").match(/(?<previous>\A.*?)(?<body><body[^>]*>.*?)(?<report><report[^>]*>.*?<\/report>)(?<after>.*)\z/m)

      @body       = matches[:body]
      @previous   = matches[:previous]
      @after      = matches[:after]
      @report_xml = matches[:report]
    end

    def build_report_structure
      parsed = Nokogiri::HTML.parse(@report_xml)
      report = parsed.search("report")

      report_node = report.first
      @pagination = report_node["pagination"] == "true"
      @orientation = report_node["orientation"]&.downcase
      @paper       = report_node["paper"]

      if @pagination
        @pagination_labels[:first] = report_node["pagination-first"] if report_node["pagination-first"]
        @pagination_labels[:prev]  = report_node["pagination-prev"]  if report_node["pagination-prev"]
        @pagination_labels[:next]  = report_node["pagination-next"]  if report_node["pagination-next"]
        @pagination_labels[:last]  = report_node["pagination-last"]  if report_node["pagination-last"]

        # Escape for safe HTML output
        @pagination_labels.transform_values! { |v| CGI.escapeHTML(v.to_s) }
      end

      @report.header = info(report.search("> report-header").first)
      @report.footer = info(report.search("> report-footer").first)

      build_page(report)
      build_groups(report)

      last_page = report.search("report-last-page").first
      @last_page_template = last_page.inner_html if last_page
    end

    def build_page(report)
      page = report.search("report-page").first

      @page.header       = info(page.search("> report-header").first)
      @page.footer       = info(page.search("> report-footer").first)
      @page.row_template = report.search("report-row").first&.inner_html
      @page.rows         = page["rows"].to_i if page["rows"]
      @page.page         = @page
    end

    def build_groups(report)
      page = report.search("report-page").first
      ref_container = @page
      ref_element   = page

      while ref_element
        next_container = ref_element.search("> report-group").first
        break unless next_container

        container = build_group(next_container)
        ref_container.containers << container

        ref_container = container
        ref_element   = next_container
      end
    end

    def build_group(element)
      container = Container.new(element["id"], @locals, make_stats)
      container.header = info(element.search("> report-header").first)
      container.footer = info(element.search("> report-footer").first)
      container.attr   = element["attr"]
      container.reprint_header_on_page_break = element["reprint-header-on-page-break"] == "true"
      container.page   = @page
      container
    end

    def info(element)
      return { content: "" } unless element

      { content: element.inner_html }
    end

    def render_erb(content)
      return "" if content.nil? || content.empty?

      ERB.new(content).result(@page.instance_eval { binding })
    end
  end
end
