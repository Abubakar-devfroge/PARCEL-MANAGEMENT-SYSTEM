defmodule Goods.Accounts.User do
  use Ash.Resource,
    otp_app: :goods,
    domain: Goods.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAuthentication]

  authentication do
    add_ons do
      log_out_everywhere do
        apply_on_password_change? true
      end

      # confirmation :confirm_new_user do
      #   monitor_fields [:email]
      #   confirm_on_create? true
      #   confirm_on_update? false
      #   require_interaction? true
      #   confirmed_at_field :confirmed_at
      #   auto_confirm_actions [:sign_in_with_magic_link, :reset_password_with_token]
      #   sender Goods.Accounts.User.Senders.SendNewUserConfirmationEmail
      # end
    end

    tokens do
      enabled? true
      token_resource Goods.Accounts.Token
      signing_secret Goods.Secrets
      store_all_tokens? true
      require_token_presence_for_authentication? true
    end

    strategies do
      password :password do
        identity_field :email
        hash_provider AshAuthentication.BcryptProvider

        resettable do
          sender Goods.Accounts.User.Senders.SendPasswordResetEmail
          # these configurations will be the default in a future release
          password_reset_action_name :reset_password_with_token
          request_password_reset_action_name :request_password_reset_token
        end
      end

      remember_me :remember_me
    end
  end

  postgres do
    table "users"
    repo Goods.Repo
  end

  actions do
    defaults [:read]

    read :employees do
      pagination keyset?: true,
                 offset?: true,
                 required?: false,
                 default_limit: 30,
                 max_page_size: 100,
                 countable: true

      filter expr(role != :client and company_key == ^actor(:company_key))
      prepare build(sort: [inserted_at: :desc, id: :desc])
    end

    read :get_by_invite_token do
      description "Looks up a user by their invite token hash"
      get? true

      argument :invite_token, :string do
        allow_nil? false
        sensitive? true
      end

      filter expr(invite_token == ^arg(:invite_token))
    end

    read :get_by_subject do
      description "Get a user by the subject claim in a JWT"
      argument :subject, :string, allow_nil?: false
      get? true
      prepare AshAuthentication.Preparations.FilterBySubject
    end

    update :change_password do
      # Use this action to allow users to change their password by providing
      # their current password and a new password.

      require_atomic? false
      accept []
      argument :current_password, :string, sensitive?: true, allow_nil?: false

      argument :password, :string,
        sensitive?: true,
        allow_nil?: false,
        constraints: [min_length: 8]

      argument :password_confirmation, :string, sensitive?: true, allow_nil?: false

      validate confirm(:password, :password_confirmation)

      validate {AshAuthentication.Strategy.Password.PasswordValidation,
                strategy_name: :password, password_argument: :current_password}

      change {AshAuthentication.Strategy.Password.HashPasswordChange, strategy_name: :password}
    end

    read :sign_in_with_password do
      description "Attempt to sign in using a email and password."
      get? true

      argument :email, :ci_string do
        description "The email to use for retrieving the user."
        allow_nil? false
      end

      argument :password, :string do
        description "The password to check for the matching user."
        allow_nil? false
        sensitive? true
      end

      # validates the provided email and password and generates a token
      prepare AshAuthentication.Strategy.Password.SignInPreparation

      metadata :token, :string do
        description "A JWT that can be used to authenticate the user."
        allow_nil? false
      end
    end

    read :sign_in_with_token do
      # In the generated sign in components, we validate the
      # email and password directly in the LiveView
      # and generate a short-lived token that can be used to sign in over
      # a standard controller action, exchanging it for a standard token.
      # This action performs that exchange. If you do not use the generated
      # liveviews, you may remove this action, and set
      # `sign_in_tokens_enabled? false` in the password strategy.

      description "Attempt to sign in using a short-lived sign in token."
      get? true

      argument :token, :string do
        description "The short-lived sign in token."
        allow_nil? false
        sensitive? true
      end

      # validates the provided sign in token and generates a token
      prepare AshAuthentication.Strategy.Password.SignInWithTokenPreparation

      metadata :token, :string do
        description "A JWT that can be used to authenticate the user."
        allow_nil? false
      end
    end

    create :register_with_password do
      description "Register a new user with a email and password."

      argument :email, :ci_string do
        allow_nil? false
      end

      argument :password, :string do
        description "The proposed password for the user, in plain text."
        allow_nil? false
        constraints min_length: 8
        sensitive? true
      end

      argument :password_confirmation, :string do
        description "The proposed password for the user (again), in plain text."
        allow_nil? false
        sensitive? true
      end

      # Sets the email from the argument
      change set_attribute(:email, arg(:email))

      # Hashes the provided password
      change AshAuthentication.Strategy.Password.HashPasswordChange

      # Defaults to :client when role is not provided.
      change Goods.Accounts.User.Changes.AssignBootstrapRole

      # Generates an authentication token for the user
      change AshAuthentication.GenerateTokenChange

      # validates that the password matches the confirmation
      validate AshAuthentication.Strategy.Password.PasswordConfirmationValidation

      metadata :token, :string do
        description "A JWT that can be used to authenticate the user."
        allow_nil? false
      end
    end

    create :create_employee do
      description "Create an employee account (admin/agent) and mark it invited."

      accept []

      argument :name, :string do
        allow_nil? false
      end

      argument :email, :ci_string do
        allow_nil? false
      end

      argument :role, :atom do
        allow_nil? false
        constraints one_of: [:admin, :agent]
      end

      argument :invite_token, :string do
        allow_nil? false
        sensitive? true
        public? false
      end

      argument :invite_sent_at, :utc_datetime_usec do
        allow_nil? false
        public? false
      end

      change set_attribute(:name, arg(:name))
      change set_attribute(:email, arg(:email))
      change set_attribute(:role, arg(:role))
      change set_attribute(:company_key, actor(:company_key))
      change set_attribute(:invite_token, arg(:invite_token))
      change set_attribute(:invite_sent_at, arg(:invite_sent_at))

      # Retains explicit role provided by admins; only defaults to :client when nil.
      change Goods.Accounts.User.Changes.AssignBootstrapRole
    end

    update :set_role_internal do
      description "Internal role update used by company bootstrap logic."

      require_atomic? false

      accept []

      argument :target_role, :atom do
        allow_nil? false
        constraints one_of: [:admin, :agent, :client]
      end

      change set_attribute(:role, arg(:target_role))
    end

    update :set_company_key_internal do
      description "Internal company key update used by onboarding bootstrap logic."

      require_atomic? false

      accept []

      argument :target_company_key, :string do
        allow_nil? false
      end

      change set_attribute(:company_key, arg(:target_company_key))
    end

    action :request_password_reset_token do
      description "Send password reset instructions to a user if they exist."

      argument :email, :ci_string do
        allow_nil? false
      end

      # creates a reset token and invokes the relevant senders
      run {AshAuthentication.Strategy.Password.RequestPasswordReset, action: :get_by_email}
    end

    read :get_by_email do
      description "Looks up a user by their email"
      get_by :email
    end

    update :reset_password_with_token do
      argument :reset_token, :string do
        allow_nil? false
        sensitive? true
      end

      argument :password, :string do
        description "The proposed password for the user, in plain text."
        allow_nil? false
        constraints min_length: 8
        sensitive? true
      end

      argument :password_confirmation, :string do
        description "The proposed password for the user (again), in plain text."
        allow_nil? false
        sensitive? true
      end

      # validates the provided reset token
      validate AshAuthentication.Strategy.Password.ResetTokenValidation

      # validates that the password matches the confirmation
      validate AshAuthentication.Strategy.Password.PasswordConfirmationValidation

      # Hashes the provided password
      change AshAuthentication.Strategy.Password.HashPasswordChange

      # Generates an authentication token for the user
      change AshAuthentication.GenerateTokenChange
    end

    update :set_password_from_invite do
      description "Set the initial password using a valid invite token flow."

      require_atomic? false
      accept []

      argument :password, :string do
        description "The proposed password for the user, in plain text."
        allow_nil? false
        constraints min_length: 8
        sensitive? true
      end

      argument :password_confirmation, :string do
        description "The proposed password for the user (again), in plain text."
        allow_nil? false
        sensitive? true
      end

      validate confirm(:password, :password_confirmation)

      # Hashes the provided password
      change AshAuthentication.Strategy.Password.HashPasswordChange

      # One-time invite use only.
      change set_attribute(:invite_token, nil)
      change set_attribute(:invite_sent_at, nil)
    end
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end

    policy action(:read) do
      authorize_if actor_attribute_equals(:role, :admin)
      authorize_if expr(id == ^actor(:id))
    end

    policy action(:employees) do
      authorize_if expr(^actor(:role) == :admin and not is_nil(^actor(:company_key)))
    end

    policy action(:create_employee) do
      authorize_if expr(^actor(:role) == :admin and not is_nil(^actor(:company_key)))
    end

    policy action(:get_by_invite_token) do
      authorize_if always()
    end

    policy action(:set_password_from_invite) do
      authorize_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string

    attribute :role, :atom do
      allow_nil? false
      constraints one_of: [:admin, :agent, :client]
      default :client
      public? true
    end

    attribute :company_key, :string

    attribute :email, :ci_string do
      allow_nil? false
      public? true
    end

    attribute :hashed_password, :string do
      allow_nil? true
      sensitive? true
    end

    attribute :invite_token, :string do
      sensitive? true
    end

    attribute :invite_sent_at, :utc_datetime_usec

    attribute :confirmed_at, :utc_datetime_usec

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_email, [:email]
  end
end
