require 'open-uri'
require 'net/http'

class VehicleImageDownloaderJob < ApplicationJob
  queue_as :default
  
  # Retry при ошибках сети
  retry_on StandardError, wait: :polynomially_longer, attempts: 3
  
  def perform(vehicle_id)
    vehicle = Vehicle.find_by(id: vehicle_id)
    
    unless vehicle
      Rails.logger.error("VehicleImageDownloaderJob: Vehicle #{vehicle_id} not found")
      return
    end
    
    # Загружаем только для завершённых аукционов
    unless vehicle.auction_status.in?(%w[sold not_sold buy_now completed])
      Rails.logger.info("VehicleImageDownloaderJob: Skipping vehicle #{vehicle_id} - auction status is #{vehicle.auction_status}")
      return
    end
    
    # Проверяем, есть ли уже локальные изображения
    if vehicle.images.attached?
      Rails.logger.info("VehicleImageDownloaderJob: Vehicle #{vehicle_id} already has local images")
      return
    end
    
    image_urls = vehicle.image_urls || []
    
    if image_urls.empty?
      Rails.logger.info("VehicleImageDownloaderJob: Vehicle #{vehicle_id} has no image URLs")
      return
    end
    
    Rails.logger.info("VehicleImageDownloaderJob: Starting download for vehicle #{vehicle_id} (#{image_urls.size} images)")
    
    downloaded_count = 0
    failed_count = 0
    
    image_urls.each_with_index do |url, index|
      next unless url.present? && url.match?(/\Ahttps?:\/\/.+\z/)
      
      begin
        # Загружаем изображение с таймаутом
        downloaded_image = URI.open(url, read_timeout: 10, open_timeout: 5)
        
        # Определяем расширение файла
        extension = determine_extension(url, downloaded_image.content_type)
        filename = "#{vehicle.stock_number || vehicle.source_id}_#{index + 1}.#{extension}"
        
        # Прикрепляем через ActiveStorage
        vehicle.images.attach(
          io: downloaded_image,
          filename: filename,
          content_type: downloaded_image.content_type || 'image/jpeg'
        )
        
        downloaded_count += 1
        Rails.logger.debug("VehicleImageDownloaderJob: Downloaded image #{index + 1}/#{image_urls.size} for vehicle #{vehicle_id}")
        
        # Небольшая задержка между загрузками
        sleep(0.5) if index < image_urls.size - 1
        
      rescue => e
        failed_count += 1
        Rails.logger.error("VehicleImageDownloaderJob: Failed to download image #{url} for vehicle #{vehicle_id}: #{e.message}")
        # Продолжаем загрузку остальных изображений
      end
    end
    
    Rails.logger.info("VehicleImageDownloaderJob: Completed for vehicle #{vehicle_id} - downloaded: #{downloaded_count}, failed: #{failed_count}")
    
    # Опционально: оптимизируем изображения после загрузки
    if downloaded_count > 0
      optimize_images(vehicle)
    end
  end
  
  private
  
  def determine_extension(url, content_type)
    # Определяем расширение из URL или content_type
    if url.match?(/\.(jpg|jpeg)$/i)
      'jpg'
    elsif url.match?(/\.png$/i)
      'png'
    elsif url.match?(/\.webp$/i)
      'webp'
    elsif content_type&.include?('jpeg') || content_type&.include?('jpg')
      'jpg'
    elsif content_type&.include?('png')
      'png'
    elsif content_type&.include?('webp')
      'webp'
    else
      'jpg' # По умолчанию JPEG
    end
  end
  
  def optimize_images(vehicle)
    # Оптимизация изображений (требует ImageMagick или аналогичную библиотеку)
    # В production можно использовать ActiveStorage::Variant или внешний сервис
    
    # Пример оптимизации через ImageMagick (если доступен):
    # vehicle.images.each do |image|
    #   # Создаём варианты разных размеров
    #   image.variant(resize_to_limit: [1920, 1080], quality: 85).processed
    # end
    
    Rails.logger.debug("VehicleImageDownloaderJob: Image optimization skipped (requires ImageMagick)")
  end
end


