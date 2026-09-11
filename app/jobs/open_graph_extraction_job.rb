class OpenGraphExtractionJob < ApplicationJob
  queue_as :default

  URL_REGEX = %r{https?://\S+}

  def perform(record)
    urls(record.content).each do |url|
      data = extract_from(url)
      next unless data && data[:title] && data[:description] && data[:url]

      record.resource_descriptions.create!(
        title: data[:title],
        description: data[:description],
        url: data[:url],
        image_url: data[:image_url],
        byte_size: data[:byte_size]
      )
    end
  end

  private

  def urls(content)
    content.to_s.scan(URL_REGEX)
  end

  def extract_from(url)
    response = Faraday.get(url)
    return nil unless response.success?

    doc = Nokogiri::HTML(response.body)

    {
      title: meta_content(doc, "og:title"),
      description: meta_content(doc, "og:description"),
      url: meta_content(doc, "og:url") || url,
      image_url: meta_content(doc, "og:image"),
      byte_size: image_byte_size(meta_content(doc, "og:image"))
    }
  rescue Faraday::Error, URI::InvalidURIError => e
    Rails.logger.warn("OpenGraphExtractionJob: failed to fetch #{url}: #{e.message}")
    nil
  end

  def meta_content(doc, property)
    doc.at("meta[property='#{property}']")&.[]("content")
  end

  def image_byte_size(image_url)
    return nil if image_url.blank?

    response = Faraday.head(image_url)
    response.headers["content-length"]&.to_i
  rescue Faraday::Error
    nil
  end
end
