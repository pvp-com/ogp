require 'oga'
require 'ostruct'

REQUIRED_ATTRIBUTES = %w(title type image url).freeze

module OGP
  class OpenGraph
    # Required Accessors
    attr_accessor :title, :type, :url
    attr_accessor :images

    # Optional Accessors
    attr_accessor :description, :determiner, :site_name
    attr_accessor :audios
    attr_accessor :locales
    attr_accessor :videos

    def initialize(source)
      if source.nil? || source.empty?
        raise ArgumentError, '`source` cannot be nil or empty.'
      end

      raise MalformedSourceError unless source.include?('</html>')

      source.force_encoding('UTF-8') if source.encoding != 'UTF-8'

      self.images = []
      self.audios = []
      self.locales = []
      self.videos = []

      document = Nokogiri::HTML::Document.parse(source)
      parse_attributes(document)
    end

    def image
      return if images.nil?
      images.first
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
            instance_variable_set("@#{attribute_name}", attribute['content'])
        end
      end
      if self.title.blank?
        self.title=document.title
      end
      if self.description.blank?
        self.title=document.at('meta[name="description"]').try(:[], 'content')
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
