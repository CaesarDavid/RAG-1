defmodule LocalRag.Repo do
  use Ecto.Repo,
    otp_app: :local_rag,
    adapter: Ecto.Adapters.Postgres

  def init(_context, config) do
    {:ok, Keyword.put(config, :types, LocalRag.PostgrexTypes)}
  end
end
