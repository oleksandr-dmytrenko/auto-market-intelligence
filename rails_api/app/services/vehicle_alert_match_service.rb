class VehicleAlertMatchService
  def self.check_alerts_for_vehicle(vehicle)
    return unless vehicle.is_a?(Vehicle)
    
    # Only check alerts for active vehicles (newly added or recently updated)
    return unless vehicle.auction_status.in?(%w[active upcoming])
    
    # Get all active, non-expired alerts
    alerts = VehicleAlert.active.not_expired.includes(:user)
    
    matches = []
    
    alerts.find_each do |alert|
      if alert.matches_vehicle?(vehicle)
        matches << alert
      end
    end
    
    matches
  end

  def self.check_all_alerts
    # Get all active, non-expired alerts
    alerts = VehicleAlert.active.not_expired.includes(:user)
    
    # Get recently added/updated active vehicles (last 24 hours)
    # This is a fallback for vehicles that might have been missed by the after_commit callback
    recent_vehicles = Vehicle.where(auction_status: ['active', 'upcoming'])
                            .where('created_at > ? OR updated_at > ?', 24.hours.ago, 24.hours.ago)
    
    notifications_sent = 0
    
    alerts.find_each do |alert|
      recent_vehicles.find_each do |vehicle|
        # Skip if already notified
        next if alert.notified_vehicle_ids.include?(vehicle.id.to_s)
        
        if alert.matches_vehicle?(vehicle)
          # Send notification
          VehicleAlertNotificationJob.perform_later(alert.id, vehicle.id)
          alert.mark_vehicle_notified!(vehicle.id)
          notifications_sent += 1
        end
      end
    end
    
    notifications_sent
  end

end

