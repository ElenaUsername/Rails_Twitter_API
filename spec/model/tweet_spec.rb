require 'rails_helper'

describe 'Callback for before_create:generate_uuid' do
  it 'UUID was automaticaly created' do
    tweet = Tweet.create(content: 'Test that UUID is created')
    expect(tweet.uuid).to be_present
    expect(tweet.uuid.length).to eq(36)
  end

  it 'Two UUID generated should be unique' do
    tweet_first = Tweet.create(content: "First tweet")
    tweet_second = Tweet.create(content: "First tweet")

    expect(tweet_first).to be_present
    expect(tweet_second).to be_present
    expect(tweet_first.uuid).not_to be(tweet_second.uuid)
  end
end
