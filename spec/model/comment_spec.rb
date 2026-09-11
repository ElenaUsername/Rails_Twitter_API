require 'rails_helper'

describe Comment do
  let(:tweet) { Tweet.create!(content: 'Best thing I found in a while: https://12ft.io/') }

  it 'generates a UUID on create' do
    comment = tweet.comments.create!(content: 'This is exactly the ladder I needed')

    expect(comment.uuid).to be_present
    expect(comment.uuid.length).to eq(36)
  end

  it 'generates a distinct UUID per comment' do
    first = tweet.comments.create!(content: 'First comment')
    second = tweet.comments.create!(content: 'Second comment')

    expect(first.uuid).not_to eq(second.uuid)
  end

  it 'rejects a duplicate UUID at the database level' do
    first = tweet.comments.create!(content: 'First comment')
    second = tweet.comments.create!(content: 'Second comment')

    expect { second.update!(uuid: first.uuid) }
      .to raise_error(ActiveRecord::RecordNotUnique)
  end

  it 'exposes content as message' do
    comment = tweet.comments.create!(content: 'Nice ladder')

    expect(comment.message).to eq('Nice ladder')
  end

  it 'requires content' do
    comment = tweet.comments.build(content: '')

    expect(comment).not_to be_valid
  end

  it 'requires a tweet' do
    comment = Comment.new(content: 'Orphan comment')

    expect(comment).not_to be_valid
  end

  it 'has resource_descriptions of its own, exposed as resources' do
    comment = tweet.comments.create!(content: 'There is one link')

    comment.resource_descriptions.create!(
      title: 'Example',
      description: 'Example description',
      url: 'https://api.example.com',
      image_url: 'https://api.example.com/image.png',
      byte_size: 123
    )

    expect(comment.resources.count).to eq(1)
    expect(comment.resources.last.image_url).to eq('https://api.example.com/image.png')
    expect(comment.resources.last.byte_size).to eq(123)
  end
end
