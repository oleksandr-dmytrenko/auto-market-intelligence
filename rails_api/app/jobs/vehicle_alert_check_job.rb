class VehicleAlertCheckJob < ApplicationJob
  queue_as :default

  def perform(vehicle_id)
    vehicle = Vehicle.find_by(id: vehicle_id)
    return unless vehicle
    return unless vehicle.auction_status.in?(%w[active upcoming])
    
    # Get all active, non-expired alerts
    alerts = VehicleAlert.active.not_expired.includes(:user)
    
    alerts.find_each do |alert|
      if alert.matches_vehicle?(vehicle)
        # Send notification asynchronously
        VehicleAlertNotificationJob.perform_later(alert.id, vehicle.id)
        alert.mark_vehicle_notified!(vehicle.id)
      end
    end
  rescue => e
    Rails.logger.error("Error checking vehicle alerts: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
  end
end

