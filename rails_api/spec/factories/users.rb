FactoryBot.define do
  factory :user do
    telegram_id { rand(100000000..999999999) }
    username { "user_#{rand(1000..9999)}" }
  end
end



