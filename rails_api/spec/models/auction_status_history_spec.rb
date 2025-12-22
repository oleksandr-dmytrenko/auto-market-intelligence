require 'rails_helper'

RSpec.describe AuctionStatusHistory, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:new_status) }
    it { should validate_presence_of(:changed_at) }
    it { should validate_inclusion_of(:new_status).in_array(%w[active upcoming sold not_sold buy_now archived completed]) }
    it { should validate_inclusion_of(:old_status).in_array(%w[active upcoming sold not_sold buy_now archived completed]).allow_nil }
  end

  describe 'associations' do
    it { should belong_to(:vehicle) }
  end

  describe 'scopes' do
    let!(:history1) { create(:auction_status_history, new_status: 'sold', changed_at: 1.day.ago) }
    let!(:history2) { create(:auction_status_history, new_status: 'active', changed_at: 2.days.ago) }

    it 'orders by recent' do
      expect(AuctionStatusHistory.recent.first).to eq(history1)
    end

    it 'filters by status' do
      expect(AuctionStatusHistory.by_status('sold')).to include(history1)
      expect(AuctionStatusHistory.by_status('sold')).not_to include(history2)
    end
  end

  describe 'creation' do
    it 'creates valid history' do
      vehicle = create(:vehicle)
      history = build(:auction_status_history, vehicle: vehicle)
      expect(history).to be_valid
    end
  end
end


