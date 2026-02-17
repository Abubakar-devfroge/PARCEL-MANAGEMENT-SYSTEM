defmodule Logistics.ParcelBooking do
  use Ash.Resource,
    otp_app: :goods,
    domain: Logistics,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "parcel_bookings"
    repo Goods.Repo
  end

  actions do
    defaults [:read, :destroy]

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
        :destination,
        :parcel_type,
        :quantity,
        :price
      ]
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

  attributes do
    uuid_primary_key :id, generated?: true
    create_timestamp :inserted_at
    update_timestamp :updated_at
    attribute :parcel_number, :string

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
