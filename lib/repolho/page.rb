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
    end

    def rows=(number)
      @rows = number
      @valid_rows = @rows
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
