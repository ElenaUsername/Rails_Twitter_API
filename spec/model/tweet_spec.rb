require 'rails_helper'

describe 'Callback for before_create:generate_uuid' do
  it 'UUID was automaticaly created' do
    tweet = Tweet.create(content: 'Test that UUID is created')
    expect(tweet.uuid).to be_present
    expect(tweet.uuid.length).to eq(36)
  end

  it 'two UUID generated should be unique' do
    tweet_first = Tweet.create(content: "First tweet")
    tweet_second = Tweet.create(content: "First tweet")

    expect(tweet_first).to be_present
    expect(tweet_second).to be_present
    expect(tweet_first.uuid).not_to be(tweet_second.uuid)
  end

  it 'has one resource_description' do
    tweet = Tweet.create!(content: 'There is one link')

    tweet.resource_descriptions.create!(
      title: 'Example',
      description: 'Example description',
      url: 'https://api.example.com',
      image_url: 'https://api.example.com/image.png',
      byte_size: 123
    )

    expect(tweet.resource_descriptions.count).to eq(1)
  end

  it 'has many resource_descriptions' do
    tweet = Tweet.create!(content: 'There are two links')

    tweet.resource_descriptions.create!(
      title: 'Example one',
      description: 'First example description',
      url: 'https://api.example.com/one',
      image_url: 'https://api.example.com/one.png',
      byte_size: 123
    )

    tweet.resource_descriptions.create!(
      title: 'Example two',
      description: 'Second example description',
      url: 'https://api.example.com/two',
      image_url: 'https://api.example.com/two.png',
      byte_size: 456
    )

    expect(tweet.resource_descriptions.count).to eq(2)
  end
end
