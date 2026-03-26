defmodule GoodsWeb.AuthOverrides do
  use AshAuthentication.Phoenix.Overrides

  alias AshAuthentication.Phoenix.{
    Components,
    ConfirmLive,
    MagicSignInLive,
    ResetLive,
    SignInLive
  }

  # configure your UI overrides here

  # First argument to `override` is the component name you are overriding.
  # The body contains any number of configurations you wish to override
  # Below are some examples

  # For a complete reference, see https://hexdocs.pm/ash_authentication_phoenix/ui-overrides.html

  override AshAuthentication.Phoenix.Components.Banner do
    set :image_url, false
    set :text_class, "bg-black"
  end

  # override AshAuthentication.Phoenix.Components.SignIn do
  #  set :show_banner, false
  # end

  override SignInLive do
    set :root_class,
        "bg-white flex items-center justify-center px-4 sm:px-6 md:px-8 min-h-[90dvh]"
  end

  override ResetLive do
    set :root_class, "min-h-screen bg-white flex items-center justify-center px-4 sm:px-6 md:px-8"
  end

  override ConfirmLive do
    set :root_class, "min-h-screen bg-white flex items-center justify-center px-4 sm:px-6 md:px-8"
  end

  override MagicSignInLive do
    set :root_class, "min-h-screen bg-white flex items-center justify-center px-4 sm:px-6 md:px-8"
  end

  override Components.SignIn do
    set :strategy_class, "w-full max-w-3xl p-6 sm:p-8"
  end

  override Components.Reset do
    set :strategy_class, "w-full max-w-3xl p-6 sm:p-8"
  end

  override Components.Confirm do
    set :strategy_class, "w-full max-w-3xl p-6 sm:p-8"
  end

  override Components.MagicLink do
    set :root_class, "w-full max-w-3xl p-6 sm:p-8"
  end

  override Components.Password do
    set :interstitial_class,
        "flex flex-row justify-between content-between text-sm font-medium text-gray-500"

    set :toggler_class,
        "flex-none text-gray-700 hover:text-gray-900 px-2 first:pl-0 last:pr-0 transition-colors duration-200"
  end

  override Components.Password.Input do
    set :input_class,
        "w-full rounded-md border border-gray-300 bg-white px-6 py-2 text-base text-gray-900 focus:border-blue-600 focus:ring-4 focus:ring-blue-600/10 transition"

    set :input_class_with_error,
        "w-full rounded-md border border-black bg-white px-6 py-2 text-base text-gray-900 focus:border-black focus:ring-4 focus:ring-black/10 transition"

    set :submit_class,
        "font-semibold text-base bg-black text-white rounded-md w-full px-6 py-2 hover:bg-amber-700 hover:text-white transition-colors duration-300"
  end

  override Components.MagicLink.Input do
    set :submit_class,
        "font-semibold text-base bg-black text-white rounded-md w-full px-6 py-2 hover:bg-amber-700 hover:text-white transition-colors duration-300"
  end
end
