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












# RSpec.describe Tweet, type: :model do
#   describe 'callbacks' do
#     describe 'before_create :generate_uuid' do
#       it 'generates a UUID automatically when created' do
#         tweet = Tweet.create(content: 'Hello world')

#         expect(tweet.uuid).to be_present
#         expect(tweet.uuid).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i)
#       end

#       it 'generates unique UUIDs for different tweets' do
#         tweet1 = Tweet.create(content: 'First tweet')
#         tweet2 = Tweet.create(content: 'Second tweet')

#         expect(tweet1.uuid).not_to eq(tweet2.uuid)
#       end
#     end
#   end
# end
