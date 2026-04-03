defmodule Logistics.ParcelBooking do
  use Ash.Resource,
    otp_app: :goods,
    domain: Logistics,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "parcel_bookings"
    repo Goods.Repo
  end

  actions do
    defaults [:destroy]

    read :read do
      primary? true

      pagination keyset?: true,
                 offset?: true,
                 required?: false,
                 default_limit: 40,
                 max_page_size: 100,
                 countable: true
    end

    create :create do
      primary? true
      change Logistics.Changes.GenerateParcelNumber

      accept [
        :sender_name,
        :sender_id,
        :sender_phone,
        :receiver_name,
        :receiver_id,
        :receiver_phone,
        :origin_office_id,
        :destination_office_id,
        :route_id,
        :destination,
        :parcel_type,
        :quantity,
        :price
      ]
    end

    update :update do
      primary? true

      accept [
        :sender_name,
        :sender_id,
        :sender_phone,
        :receiver_name,
        :receiver_id,
        :receiver_phone,
        :origin_office_id,
        :destination_office_id,
        :route_id,
        :destination,
        :parcel_type,
        :quantity,
        :price
      ]
    end
  end

  policies do
    policy action(:create) do
      authorize_if expr(not is_nil(^actor(:id)) and not is_nil(^actor(:company_key)))
    end

    policy action_type([:read, :update, :destroy]) do
      authorize_if expr(not is_nil(^actor(:company_key)) and company_key == ^actor(:company_key))
    end
  end

  validations do
    validate string_length(:sender_name, min: 3),
      message: "Sender name is too short. Use at least 3 letters."

    validate string_length(:sender_name, max: 15),
      message: "Sender name is too long. Use 15 letters or less."

    validate string_length(:receiver_name, min: 3),
      message: "Receiver name is too short. Use at least 3 letters."

    validate string_length(:receiver_name, max: 15),
      message: "Receiver name is too long. Use 15 letters or less."
  end

  multitenancy do
    strategy :attribute
    attribute :company_key
  end

  attributes do
    uuid_primary_key :id, generated?: true
    create_timestamp :inserted_at
    update_timestamp :updated_at
    attribute :parcel_number, :string
    attribute :company_key, :string

    attribute :sender_name, :string do
      allow_nil? false
    end

    attribute :sender_id, :string do
      allow_nil? false
    end

    attribute :sender_phone, :string do
      allow_nil? false
    end

    attribute :receiver_name, :string do
      allow_nil? false
    end

    attribute :receiver_id, :string

    attribute :receiver_phone, :string do
      allow_nil? false
    end

    attribute :origin_office_id, :string

    attribute :destination_office_id, :string

    attribute :route_id, :string

    attribute :destination, :string do
      allow_nil? false
    end

    attribute :parcel_type, :string do
      allow_nil? false
    end

    attribute :quantity, :integer do
      allow_nil? false
    end

    attribute :price, :decimal do
      allow_nil? false
    end
  end
end
