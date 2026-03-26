defmodule Goods.Accounts.BusinessProfile do
  use Ash.Resource,
    otp_app: :goods,
    domain: Goods.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "business_profiles"
    repo Goods.Repo
  end

  actions do
    defaults [:read]

    create :create do
      primary? true

      accept [
        :company_name,
        :business_type,
        :country,
        :primary_city,
        :business_phone,
        :brand_logo,
        :base_office,
        :branch_offices,
        :delivery_destinations,
        :transfer_points,
        :valid_routes
      ]

      change set_attribute(:user_id, actor(:id))
    end

    update :update do
      primary? true

      accept [
        :company_name,
        :business_type,
        :country,
        :primary_city,
        :business_phone,
        :brand_logo,
        :base_office,
        :branch_offices,
        :delivery_destinations,
        :transfer_points,
        :valid_routes
      ]
    end
  end

  policies do
    policy action(:create) do
      authorize_if actor_present()
    end

    policy action_type([:read, :update]) do
      authorize_if expr(user_id == ^actor(:id))
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :company_name, :string do
      allow_nil? false
    end

    attribute :business_type, :string do
      allow_nil? false
    end

    attribute :country, :string do
      allow_nil? false
    end

    attribute :primary_city, :string do
      allow_nil? false
    end

    attribute :business_phone, :string do
      allow_nil? false
    end

    attribute :brand_logo, :string do
      constraints match: ~r/^(https?:\/\/|\/).+\.(?:png|jpe?g|gif|webp|svg)(?:\?.*)?$/i
    end

    attribute :base_office, :string

    attribute :branch_offices, :string

    attribute :delivery_destinations, :string

    attribute :transfer_points, :string

    attribute :valid_routes, :string

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :user, Goods.Accounts.User do
      allow_nil? false
      attribute_writable? true
    end
  end

  identities do
    identity :unique_business_profile_per_user, [:user_id]
  end
end
