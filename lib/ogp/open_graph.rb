require 'ostruct'

REQUIRED_ATTRIBUTES = %w(title type image url).freeze

module OGP
  class OpenGraph
    attr_accessor :source, :attributes

    def initialize(source)
      body = source.try(:body)
      if body.nil? || body.empty?
        raise ArgumentError, 'body cannot be nil or empty.'
      end

      raise MalformedbodyError unless body.include?('</html>')

      body.force_encoding('UTF-8') if body.encoding != 'UTF-8'

      self.source = source
      document = Nokogiri::HTML::Document.parse(body)
      self.attributes = parse_attributes(document)
    end

    def image
      return nil if images.nil?
      res = images.first.try(:url)
      return nil if res.nil?
      begin
        uri = URI.parse(res)
        if uri.scheme.blank? || uri.host.blank?
          main_uri = URI.parse(url)
          res.scheme = main_uri.scheme 
          res.host = main_uri.host 
        end
        return res.to_s
      rescue StandardError => e
        return nil
      end
    end

  private

    # rubocop:disable Metrics/CyclomaticComplexity
    def parse_attributes(document)
      hash = {}
      keys = document.xpath('//head/meta[starts-with(@property, \'og:\')]').map{|tag| tag.attributes['property'].value }.uniq
      keys.each do |key|
        hash[key.tr(":", "_").to_sym] = document.xpath("//*[@property='#{key}']").map{|meta_og| meta_og.attributes['content'].value}
      end
      hash[:html_title]=document.title
      hash[:html_description]=document.at('meta[name="description"]').try(:[], 'content')
      hash[:html_url] = source.request.uri.to_s
      hash
    end

    def attribute_exists(document, name)
      document.at_xpath("boolean(//head/meta[@property='og:#{name}'])")
    end
  end

  class MissingAttributeError < StandardError
  end

  class MalformedSourceError < StandardError
  end
end
