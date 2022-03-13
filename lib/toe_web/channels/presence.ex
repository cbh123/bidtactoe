defmodule ToeWeb.Presence do
  use Phoenix.Presence,
    otp_app: :toe,
    pubsub_server: Toe.PubSub
end
