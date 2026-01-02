FactoryBot.define do
  factory :vehicle do
    source { 'iaai' }
    source_id { "IA#{rand(100000..999999)}" }
    make { 'Toyota' }
    model { 'Camry' }
    year { 2020 }
    mileage { 50000 }
    color { 'Black' }
    damage_type { 'None' }
    price { 15000.00 }
    auction_status { 'completed' }
    final_price { 15000.00 }
    location { 'Los Angeles, CA' }
    auction_url { 'https://example.com/auction/123' }
    image_urls { ['https://example.com/image1.jpg'] }
    stock_number { "ST#{rand(100000..999999)}" }
    partial_vin { '1HGBH41JXMN' }
    vehicle_fingerprint { 'abc123def456' }
    mileage_bucket { '50-75k' }

    trait :active do
      auction_status { 'active' }
      final_price { nil }
    end

    trait :sold do
      auction_status { 'sold' }
      final_price { 15000.00 }
    end

    trait :copart do
      source { 'copart' }
      source_id { "CP#{rand(100000..999999)}" }
    end

    trait :with_vin do
      vin { '1HGBH41JXMN109186' }
    end
  end
end



