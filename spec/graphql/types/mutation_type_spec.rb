require "rails_helper"

RSpec.describe Types::MutationType do
  subject(:mutation_type) { described_class }

  it "verify the expected fields existance" do
    expect(mutation_type.fields.keys).to contain_exactly(
      "tweetCreate",
      "commentCreate",
    )
  end
end
