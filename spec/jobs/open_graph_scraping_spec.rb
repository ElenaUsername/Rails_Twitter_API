require "rails_helper"

RSpec.describe OpenGraphScraping, type: :job do
  subject(:open_graph_scraping) { described_class.new }

  describe "#extract_urls_from_content" do
  let(:content) { "Check out this link: https://example.com and also visit http://test.com" }

    it "extracts URLs from content" do
      urls = open_graph_scraping.extract_urls_from_content(content)
      expect(urls).to eq([ "https://example.com", "http://test.com" ])
    end
  end

  describe "#extract_image_from_url" do
    let(:mock_response) { <<-HTML }
      <html>
        <head>
          <meta property="og:url" content="https://example.com">
          <meta property="og:title" content="Example Domain">
          <meta property="og:image" content="https://example.com/image.jpg">
          <meta property="og:description" content="This is an example domain">
        </head>
      </html>
    HTML

    it "extracts Open Graph data from a URL" do
      allow(URI).to receive(:open).and_return(mock_response)
      data = open_graph_scraping.extract_image_from_url("https://example.com")
      expect(data).to eq({
        url: "https://example.com",
        title: "Example Domain",
        image: "https://example.com/image.jpg",
        description: "This is an example domain"
      })
    end
  end

  describe "#perform" do
    let(:content) { "Check out this link: https://example.com" }

    it "scrapes Open Graph data for URLs in content" do
      allow(open_graph_scraping).to receive(:extract_urls_from_content).and_return([ "https://example.com" ])
      allow(open_graph_scraping).to receive(:extract_image_from_url).and_return({
        url: "https://example.com",
        title: "Example Domain",
        image: "https://example.com/image.jpg",
        description: "This is an example domain"
      })

      expect(open_graph_scraping.perform(content)).to eq([ {
        url: "https://example.com",
        title: "Example Domain",
        image: "https://example.com/image.jpg",
        description: "This is an example domain"
      } ])
    end
  end
end
