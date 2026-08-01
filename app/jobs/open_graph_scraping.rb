require 'open-uri'

class OpenGraphScraping < ApplicationJob
  queue_as :default

  def perform(content)


    urls = extract_urls_from_content(content)
    resource_descriptions = []

    urls.each do |url|
      data = extract_image_from_url(url)
      resource_descriptions << data if data
    end

    resource_descriptions
  end

  def extract_urls_from_content(content)
    URI.extract(content, ['http', 'https'])
  end

  def extract_image_from_url(url)
    doc = Nokogiri::HTML(URI.open(url))
    url = doc.xpath('//meta[@property="og:url"]').first['content']
    title = doc.xpath('//meta[@property="og:title"]').first['content']
    image = doc.xpath('//meta[@property="og:image"]').first['content']
    description = doc.xpath('//meta[@property="og:description"]').first['content']

    data = {
      url: url,
      title: title,
      image: image,
      description: description
    }

  end

end