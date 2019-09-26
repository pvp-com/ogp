require 'ostruct'

REQUIRED_ATTRIBUTES = %w(title type image url).freeze

module OGP
  class OpenGraph
    # Required Accessors
    attr_accessor :title, :type, :url
    attr_accessor :images
    attr_accessor :source

    # Optional Accessors
    attr_accessor :description, :determiner, :site_name
    attr_accessor :audios
    attr_accessor :locales
    attr_accessor :videos

    def initialize(source)
      body = source.try(:body)
      if body.nil? || body.empty?
        raise ArgumentError, 'body cannot be nil or empty.'
      end

      raise MalformedbodyError unless body.include?('</html>')

      body.force_encoding('UTF-8') if body.encoding != 'UTF-8'

      self.source = source
      self.audios = []
      self.locales = []
      self.videos = []
      self.images = []
      document = Nokogiri::HTML::Document.parse(body)
      parse_attributes(document)
    end

    def image
      return nil if images.nil?
      res = images.first.try(:url)
      return nil if res.nil?
      begin
        uri = URI.parse(res)
        if uri.scheme.blank? || uri.host.blank?
          main_uri = URI.parse(self.url)
          uri.scheme= main_uri.scheme 
          uri.host= main_uri.host 
          res = uri.to_s
        end
      rescue StandardError => e
        return nil
      end
      return res
    end

  private

    # rubocop:disable Metrics/CyclomaticComplexity
    def parse_attributes(document)
      document.xpath('//head/meta[starts-with(@property, \'og:\')]').each do |attribute|
        attribute_name = attribute['property'].downcase.gsub('og:', '')
        case attribute_name
          when /^image$/i
            images << OpenStruct.new(url: attribute['content'].to_s)
          when /^image:(.+)/i
            images << OpenStruct.new unless images.last
            images.last[Regexp.last_match[1].gsub('-', '_')] = attribute['content'].to_s
          when /^audio$/i
            audios << OpenStruct.new(url: attribute['content'].to_s)
          when /^audio:(.+)/i
            audios << OpenStruct.new unless audios.last
            audios.last[Regexp.last_match[1].gsub('-', '_')] = attribute['content'].to_s
          when /^locale/i
            locales << attribute['content'].to_s
          when /^video$/i
            videos << OpenStruct.new(url: attribute['content'].to_s)
          when /^video:(.+)/i
            videos << OpenStruct.new unless videos.last
            videos.last[Regexp.last_match[1].gsub('-', '_')] = attribute['content'].to_s
          else
            instance_variable_set("@#{attribute_name}", attribute['content'].to_s)
        end
      end
      if self.title.blank?
        self.title=document.title
      end
      if self.description.blank?
        self.description=document.at('meta[name="description"]').try(:[], 'content')
      end
      if self.url.blank?
        self.url = source.request.uri.to_s
      end
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
