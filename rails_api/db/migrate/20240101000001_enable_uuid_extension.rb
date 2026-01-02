class EnableUuidExtension < ActiveRecord::Migration[7.1]
  def change
    enable_extension 'uuid-ossp' unless extension_enabled?('uuid-ossp')
  end
end







