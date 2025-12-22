require 'rails_helper'

RSpec.describe Vehicle, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:source) }
    it { should validate_presence_of(:source_id) }
    it { should validate_presence_of(:make) }
    it { should validate_presence_of(:model) }
    it { should validate_presence_of(:year) }
    it { should validate_numericality_of(:year).is_greater_than(1900).is_less_than_or_equal_to(Time.current.year + 1) }
    it { should validate_numericality_of(:price).is_greater_than(0).allow_nil }
    it { should validate_inclusion_of(:auction_status).in_array(%w[active completed sold not_sold buy_now upcoming archived]).allow_nil }

    it 'validates VIN format' do
      vehicle = build(:vehicle, vin: 'INVALID')
      expect(vehicle).not_to be_valid
    end

    it 'accepts valid VIN' do
      vehicle = build(:vehicle, vin: '1HGBH41JXMN109186')
      expect(vehicle).to be_valid
    end

    it 'validates partial VIN format' do
      vehicle = build(:vehicle, partial_vin: 'INVALID')
      expect(vehicle).not_to be_valid
    end

    it 'accepts valid partial VIN' do
      vehicle = build(:vehicle, partial_vin: '1HGBH41JXMN1')
      expect(vehicle).to be_valid
    end

    it 'validates image_urls format' do
      vehicle = build(:vehicle, image_urls: ['invalid-url'])
      expect(vehicle).not_to be_valid
    end

    it 'accepts valid image URLs' do
      vehicle = build(:vehicle, image_urls: ['https://example.com/image.jpg'])
      expect(vehicle).to be_valid
    end
  end

  describe 'associations' do
    it { should have_many(:auction_status_histories).dependent(:destroy) }
  end

  describe 'callbacks' do
    it 'updates status_changed_at when auction_status changes' do
      vehicle = create(:vehicle, auction_status: 'active')
      expect(vehicle.status_changed_at).to be_nil
      
      vehicle.update(auction_status: 'sold')
      expect(vehicle.status_changed_at).not_to be_nil
    end

    it 'generates vehicle_fingerprint before save' do
      vehicle = build(:vehicle, vehicle_fingerprint: nil)
      vehicle.save
      expect(vehicle.vehicle_fingerprint).not_to be_nil
    end

    it 'records status change after save' do
      # Create with explicit status to avoid default 'completed' status
      # First create with 'active', then update to 'sold' to ensure proper history
      vehicle = create(:vehicle, auction_status: 'active', final_price: nil)
      # Clear any history created during initial creation
      vehicle.auction_status_histories.destroy_all
      vehicle.reload
      vehicle.update(auction_status: 'sold')
      
      history = vehicle.auction_status_histories.last
      expect(history.old_status).to eq('active')
      expect(history.new_status).to eq('sold')
    end
  end

  describe 'scopes' do
    let!(:vehicle1) { create(:vehicle, make: 'Toyota', model: 'Camry', year: 2020, auction_status: 'completed', final_price: 15000) }
    let!(:vehicle2) { create(:vehicle, make: 'Honda', model: 'Accord', year: 2021, auction_status: 'active') }
    let!(:vehicle3) { create(:vehicle, make: 'Toyota', model: 'Camry', year: 2020, auction_status: 'sold', final_price: 20000) }

    it 'finds by partial VIN' do
      vehicle = create(:vehicle, partial_vin: '1HGBH41JXMN1', auction_status: 'completed', final_price: 15000)
      vehicle.reload
      expect(Vehicle.by_partial_vin('1HGBH41JXMN1')).to include(vehicle)
    end

    it 'finds by fingerprint' do
      vehicle = create(:vehicle, vehicle_fingerprint: 'test123')
      expect(Vehicle.by_fingerprint('test123')).to include(vehicle)
    end

    it 'finds sold vehicles' do
      expect(Vehicle.sold).to include(vehicle3)
      expect(Vehicle.sold).not_to include(vehicle2)
    end

    it 'finds by make, model, year' do
      expect(Vehicle.by_make_model_year('Toyota', 'Camry', 2020)).to include(vehicle1, vehicle3)
    end

    it 'finds completed auctions' do
      expect(Vehicle.completed_auctions).to include(vehicle1)
    end

    it 'finds active auctions' do
      expect(Vehicle.active_auctions).to include(vehicle2)
    end

    it 'finds from copart' do
      copart_vehicle = create(:vehicle, :copart)
      expect(Vehicle.from_copart).to include(copart_vehicle)
    end

    it 'finds from iaai' do
      expect(Vehicle.from_iaai).to include(vehicle1)
    end
  end

  describe 'helper methods' do
    let(:vehicle) { create(:vehicle, image_urls: ['https://example.com/image1.jpg', 'https://example.com/image2.jpg']) }

    it 'checks if has images' do
      expect(vehicle.has_images?).to be true
    end

    it 'returns image count' do
      expect(vehicle.image_count).to eq(2)
    end

    it 'returns primary image URL' do
      expect(vehicle.primary_image_url).to eq('https://example.com/image1.jpg')
    end

    it 'returns nil for primary image when no images' do
      vehicle.image_urls = []
      expect(vehicle.primary_image_url).to be_nil
    end
  end

  describe 'aggregate_by_partial_vin' do
    let!(:vehicle1) { create(:vehicle, partial_vin: '1HGBH41JXMN1', auction_status: 'sold', final_price: 15000, auction_end_date: 1.day.ago) }
    let!(:vehicle2) { create(:vehicle, partial_vin: '1HGBH41JXMN1', auction_status: 'sold', final_price: 20000, auction_end_date: 2.days.ago) }
    let!(:vehicle3) { create(:vehicle, partial_vin: '1HGBH41JXMN1', auction_status: 'active') }

    it 'aggregates sold vehicles by partial VIN' do
      result = Vehicle.aggregate_by_partial_vin('1HGBH41JXMN1')
      
      expect(result[:partial_vin]).to eq('1HGBH41JXMN1')
      expect(result[:total_sales]).to eq(2)
      expect(result[:average_price]).to eq(17500.0)
      expect(result[:lots].size).to eq(2)
    end
  end

  describe 'aggregate_by_fingerprint' do
    let(:fingerprint) { 'test_fingerprint_123' }
    let!(:vehicle1) { create(:vehicle, vehicle_fingerprint: fingerprint, auction_status: 'sold', final_price: 15000, auction_end_date: 1.day.ago) }
    let!(:vehicle2) { create(:vehicle, vehicle_fingerprint: fingerprint, auction_status: 'sold', final_price: 20000, auction_end_date: 2.days.ago) }

    it 'aggregates sold vehicles by fingerprint' do
      result = Vehicle.aggregate_by_fingerprint(fingerprint)
      
      expect(result[:fingerprint]).to eq(fingerprint)
      expect(result[:total_sales]).to eq(2)
      expect(result[:average_price]).to eq(17500.0)
    end
  end

  describe 'state machine methods' do
    let(:vehicle) { create(:vehicle, auction_status: 'active') }

    it 'marks as upcoming' do
      vehicle.mark_as_upcoming!
      expect(vehicle.auction_status).to eq('upcoming')
    end

    it 'marks as active' do
      vehicle.update(auction_status: 'completed')
      vehicle.mark_as_active!
      expect(vehicle.auction_status).to eq('active')
    end

    it 'marks as sold' do
      vehicle.mark_as_sold!(18000)
      expect(vehicle.auction_status).to eq('sold')
      expect(vehicle.final_price).to eq(18000)
    end

    it 'marks as not_sold' do
      vehicle.mark_as_not_sold!
      expect(vehicle.auction_status).to eq('not_sold')
    end

    it 'marks as buy_now' do
      vehicle.mark_as_buy_now!(20000)
      expect(vehicle.auction_status).to eq('buy_now')
      expect(vehicle.final_price).to eq(20000)
    end

    it 'marks as archived' do
      vehicle.mark_as_archived!
      expect(vehicle.auction_status).to eq('archived')
    end

    it 'marks as completed with price' do
      vehicle.mark_as_completed!(15000)
      expect(vehicle.auction_status).to eq('sold')
      expect(vehicle.final_price).to eq(15000)
    end

    it 'marks as completed without price' do
      vehicle.mark_as_completed!(0)
      expect(vehicle.auction_status).to eq('not_sold')
    end
  end
end


