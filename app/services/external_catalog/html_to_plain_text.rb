# frozen_string_literal: true

module ExternalCatalog
  class HtmlToPlainText
    BLOCK_BREAK_TAGS = %w[p div ul ol li h1 h2 h3 h4 h5 h6 tr].freeze

    def self.call(html)
      new(html).call
    end

    def initialize(html)
      @html = html.to_s
    end

    def call
      return nil if @html.blank?

      fragment = Loofah.fragment(preprocess_breaks(@html))
      fragment.css("script, style").remove

      text = fragment.text(encode_special_chars: false)
      normalize_whitespace(text)
    end

    private

    def preprocess_breaks(html)
      with_breaks = html.gsub(/<br\s*\/?>/i, "\n")
      BLOCK_BREAK_TAGS.each do |tag|
        with_breaks = with_breaks.gsub(%r{</#{tag}\s*>}i, "\n")
      end
      with_breaks
    end

    def normalize_whitespace(text)
      text
        .gsub(/\r\n?/, "\n")
        .gsub(/[ \t\f\v]+/, " ")
        .gsub(/ *\n */, "\n")
        .gsub(/\n{3,}/, "\n\n")
        .strip
        .presence
    end
  end
end
