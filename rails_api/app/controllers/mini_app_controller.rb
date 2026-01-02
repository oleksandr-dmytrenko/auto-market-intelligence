class MiniAppController < ApplicationController
  def index
    # Serve index.html for all routes (SPA routing)
    serve_file('index.html', 'text/html')
  end

  def serve_static
    # Serve static files (CSS, JS, images)
    file_name = params[:file]
    ext = File.extname(file_name)
    
    content_type = case ext
    when '.css'
      'text/css'
    when '.js'
      'application/javascript'
    when '.png', '.jpg', '.jpeg', '.gif'
      "image/#{ext[1..-1]}"
    else
      'application/octet-stream'
    end

    serve_file(file_name, content_type)
  end

  private

  def serve_file(file_name, content_type)
    file_path = Pathname.new('/mini_app').join(file_name)
    
    if File.exist?(file_path)
      # Prevent caching in development
      if Rails.env.development?
        response.headers['Cache-Control'] = 'no-cache, no-store, must-revalidate'
        response.headers['Pragma'] = 'no-cache'
        response.headers['Expires'] = '0'
      end
      
      send_file file_path, 
        type: content_type,
        disposition: 'inline',
        layout: false
    else
      render plain: "File not found: #{file_name}", status: :not_found
    end
  end
end

