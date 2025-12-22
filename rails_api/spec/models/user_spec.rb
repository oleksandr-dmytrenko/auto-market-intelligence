require 'rails_helper'

RSpec.describe User, type: :model do
  subject { build(:user) }
  
  describe 'validations' do
    it { should validate_presence_of(:telegram_id) }
    it { should validate_uniqueness_of(:telegram_id) }
  end

  describe 'associations' do
    # User model doesn't have associations defined in the codebase
  end

  describe 'creation' do
    it 'creates a valid user' do
      user = build(:user)
      expect(user).to be_valid
    end

    it 'requires telegram_id' do
      user = build(:user, telegram_id: nil)
      expect(user).not_to be_valid
    end

    it 'requires unique telegram_id' do
      create(:user, telegram_id: 123456789)
      user = build(:user, telegram_id: 123456789)
      expect(user).not_to be_valid
    end
  end
end

