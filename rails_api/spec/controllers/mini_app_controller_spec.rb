require 'rails_helper'

RSpec.describe MiniAppController, type: :controller do
  describe 'GET #index' do
    it 'serves index.html' do
      file_path = Pathname.new('/mini_app').join('index.html')
      allow(File).to receive(:exist?).with(file_path).and_return(true)
      allow(controller).to receive(:send_file).and_return(true)
      allow(controller).to receive(:performed?).and_return(true)
      
      get :index
      expect(response).to have_http_status(:ok)
    end

    it 'returns 404 when file not found' do
      file_path = Pathname.new('/mini_app').join('index.html')
      allow(File).to receive(:exist?).with(file_path).and_return(false)
      get :index
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET #serve_static' do
    it 'serves CSS files' do
      file_path = Pathname.new('/mini_app').join('styles.css')
      allow(File).to receive(:exist?).with(file_path).and_return(true)
      allow(controller).to receive(:send_file).and_return(true)
      allow(controller).to receive(:performed?).and_return(true)
      
      get :serve_static, params: { file: 'styles.css' }
      expect(response).to have_http_status(:ok)
    end

    it 'serves JS files' do
      file_path = Pathname.new('/mini_app').join('app.js')
      allow(File).to receive(:exist?).with(file_path).and_return(true)
      allow(controller).to receive(:send_file).and_return(true)
      allow(controller).to receive(:performed?).and_return(true)
      
      get :serve_static, params: { file: 'app.js' }
      expect(response).to have_http_status(:ok)
    end

    it 'returns 404 when file not found' do
      allow(File).to receive(:exist?).and_return(false)
      get :serve_static, params: { file: 'nonexistent.css' }
      expect(response).to have_http_status(:not_found)
    end
  end
end


