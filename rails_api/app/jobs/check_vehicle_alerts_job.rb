class CheckVehicleAlertsJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info("Starting vehicle alerts check...")
    
    # Check for matches
    notifications_sent = VehicleAlertMatchService.check_all_alerts
    Rails.logger.info("Sent #{notifications_sent} vehicle alert notifications")
    
    # Process expired alerts
    expired_count = VehicleAlertMatchService.process_expired_alerts
    Rails.logger.info("Processed #{expired_count} expired alerts")
    
    { notifications_sent: notifications_sent, expired_count: expired_count }
  rescue => e
    Rails.logger.error("Error in CheckVehicleAlertsJob: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise
  end
end

