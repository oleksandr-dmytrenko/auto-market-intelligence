FactoryBot.define do
  factory :auction_status_history do
    association :vehicle
    old_status { 'active' }
    new_status { 'sold' }
    price_before { 10000.00 }
    price_after { 15000.00 }
    changed_at { Time.current }
  end
end


