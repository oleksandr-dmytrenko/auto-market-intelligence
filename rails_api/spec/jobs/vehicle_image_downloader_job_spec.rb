require 'rails_helper'

RSpec.describe VehicleImageDownloaderJob, type: :job do
  let(:vehicle) { create(:vehicle, :active, image_urls: ['https://example.com/image1.jpg']) }

  before do
    ActiveJob::Base.queue_adapter = :test
  end

  describe '#perform' do
    it 'skips vehicles that are not completed' do
      vehicle.update(auction_status: 'active')
      expect {
        VehicleImageDownloaderJob.perform_now(vehicle.id)
      }.not_to raise_error
    end

    it 'skips vehicles without image URLs' do
      vehicle.update(image_urls: [])
      expect {
        VehicleImageDownloaderJob.perform_now(vehicle.id)
      }.not_to raise_error
    end

    it 'skips vehicles that already have local images' do
      allow(vehicle).to receive(:images).and_return(double(attached?: true))
      expect {
        VehicleImageDownloaderJob.perform_now(vehicle.id)
      }.not_to raise_error
    end

    it 'handles missing vehicle gracefully' do
      expect {
        VehicleImageDownloaderJob.perform_now('nonexistent-id')
      }.not_to raise_error
    end

    it 'can be enqueued' do
      # Update vehicle to sold status first to trigger callback
      vehicle.update(auction_status: 'sold')
      # Clear any jobs enqueued by callbacks
      ActiveJob::Base.queue_adapter.enqueued_jobs.clear
      
      expect {
        VehicleImageDownloaderJob.perform_later(vehicle.id)
      }.to have_enqueued_job(VehicleImageDownloaderJob)
    end
  end
end


