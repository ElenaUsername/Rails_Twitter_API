require 'rails_helper'

RSpec.describe OpenGraphExtractionJob, type: :job do
  let(:tweet) { Tweet.create!(content: content) }

  def stub_page(url, og: {})
    tags = og.map { |prop, val| %(<meta property="#{prop}" content="#{val}">) }.join
    stub_request(:get, url).to_return(status: 200, body: "<html><head>#{tags}</head></html>")
  end

  context 'when the content has a URL with full og metadata' do
    let(:content) { 'check this out https://example.com/article' }

    before do
      stub_page('https://example.com/article', og: {
        'og:title' => 'Cool Article',
        'og:description' => 'A description',
        'og:url' => 'https://example.com/article',
        'og:image' => 'https://example.com/image.png'
      })
      stub_request(:head, 'https://example.com/image.png')
        .to_return(headers: { 'Content-Length' => '12345' })
    end

    it 'creates a resource_description with the extracted data' do
      expect { described_class.perform_now(tweet.id) }
        .to change(tweet.resource_descriptions, :count).by(1)

      resource = tweet.resource_descriptions.last
      expect(resource.title).to eq('Cool Article')
      expect(resource.description).to eq('A description')
      expect(resource.url).to eq('https://example.com/article')
      expect(resource.image_url).to eq('https://example.com/image.png')
      expect(resource.byte_size).to eq(12345)
    end
  end

  context 'when the content has multiple URLs' do
    let(:content) { 'see https://example.com/a and https://example.com/b' }

    before do
      stub_page('https://example.com/a', og: {
        'og:title' => 'A', 'og:description' => 'Desc A', 'og:url' => 'https://example.com/a'
      })
      stub_page('https://example.com/b', og: {
        'og:title' => 'B', 'og:description' => 'Desc B', 'og:url' => 'https://example.com/b'
      })
    end

    it 'creates one resource_description per URL' do
      expect { described_class.perform_now(tweet.id) }
        .to change(tweet.resource_descriptions, :count).by(2)
    end
  end

  context 'when the content has no URLs' do
    let(:content) { 'just plain text, no links here' }

    it 'does not create any resource_description' do
      expect { described_class.perform_now(tweet.id) }
        .not_to change(ResourceDescription, :count)
    end
  end

  context 'when the page is missing required og tags' do
    let(:content) { 'incomplete page https://example.com/incomplete' }

    before do
      stub_page('https://example.com/incomplete', og: { 'og:title' => 'Only a title' })
    end

    it 'skips creating a resource_description' do
      expect { described_class.perform_now(tweet.id) }
        .not_to change(ResourceDescription, :count)
    end
  end

  context 'when the page is missing og:image' do
    let(:content) { 'no image https://example.com/no-image' }

    before do
      stub_page('https://example.com/no-image', og: {
        'og:title' => 'No Image', 'og:description' => 'Desc', 'og:url' => 'https://example.com/no-image'
      })
    end

    it 'still creates the resource_description with a nil image and byte_size' do
      described_class.perform_now(tweet.id)

      resource = tweet.resource_descriptions.last
      expect(resource.title).to eq('No Image')
      expect(resource.image_url).to be_nil
      expect(resource.byte_size).to be_nil
    end
  end

  context 'when the page returns a non-success response' do
    let(:content) { 'broken link https://example.com/missing' }

    before do
      stub_request(:get, 'https://example.com/missing').to_return(status: 404)
    end

    it 'skips it without raising' do
      expect { described_class.perform_now(tweet.id) }
        .not_to change(ResourceDescription, :count)
    end
  end

  context 'when fetching the page raises a Faraday error' do
    let(:content) { 'unreachable https://example.com/timeout' }

    before do
      stub_request(:get, 'https://example.com/timeout').to_timeout
    end

    it 'rescues the error, skips the URL, and does not raise' do
      expect { described_class.perform_now(tweet.id) }.not_to raise_error
      expect(tweet.resource_descriptions.count).to eq(0)
    end
  end

  context 'when the HEAD request for the image fails' do
    let(:content) { 'bad image https://example.com/bad-image' }

    before do
      stub_page('https://example.com/bad-image', og: {
        'og:title' => 'Bad Image', 'og:description' => 'Desc',
        'og:url' => 'https://example.com/bad-image', 'og:image' => 'https://example.com/broken.png'
      })
      stub_request(:head, 'https://example.com/broken.png').to_timeout
    end

    it 'still creates the resource_description with a nil byte_size' do
      described_class.perform_now(tweet.id)

      resource = tweet.resource_descriptions.last
      expect(resource.title).to eq('Bad Image')
      expect(resource.byte_size).to be_nil
    end
  end
end
