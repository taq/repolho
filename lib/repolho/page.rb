# typed: false
# frozen_string_literal: true

module Repolho
  class Page < Container
    attr_reader :content, :row_number, :rows, :page_number

    def initialize(id, locals, stats)
      super(id, locals, stats)

      @content     = []
      @rows        = 60
      @valid_rows  = @rows
      @row_number  = 1
      @page_number = 1
      @page_open   = false
      @last_page   = false
    end

    def rows=(number)
      @rows = number
      @valid_rows = @rows
    end

    def last_page?
      @last_page
    end

    def mark_as_last!
      @last_page = true
    end

    # Injects pre-rendered HTML (expected to contain <tr>s) as additional rows.
    # Each <tr> is appended individually so normal page-break logic applies.
    def inject_as_rows(html)
      return if html.nil? || html.strip.empty?

      Nokogiri::HTML(html).search("tr").each do |tr|
        check_page_break
        # After a break, status is FINISHED; reopen so later :finish can still emit the footer
        @status = STARTED if @status == FINISHED
        self << tr.to_html
      end
    end

    def <<(content)
      return unless content

      open_page unless @page_open

      content = content.is_a?(String) ? content : Array(content).join

      parsed = Nokogiri::HTML(content)
      trs    = parsed.search("tr")
      @row_number += trs.size
      @content << content
    end

    # Appends content outside the page tbodies (previous, body, after)
    def append_raw(content)
      return unless content

      @content << content
    end

    def open_page
      return if @page_open

      @content << %(<tbody class="repolho-page" data-page="#{@page_number}" style="break-after: page; page-break-after: always;">)
      @page_open = true
    end

    def close_page
      return unless @page_open

      @content << "</tbody>"
      @page_open = false
      @page_number += 1
    end

    def finalize
      close_page
    end

    private

    def check_page_break
      return unless @row_number >= @valid_rows

      @page << finish
      close_page
      reset_stats
      @row_number = 0
      @status = FINISHED

      force_header_reprint_on_children
    end
  end
end
