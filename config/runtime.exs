import Config
import Dotenvy

# Load .env (and .env.local for local overrides) in dev/test.
# In prod, real env vars take precedence and .env is optional.
source!([".env", ".env.#{config_env()}", System.get_env()])

if System.get_env("PHX_SERVER") do
  config :local_rag, LocalRagWeb.Endpoint, server: true
end

config :local_rag, LocalRagWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

# Turso credentials – loaded for all environments from env vars.
# In dev: source .env before starting (e.g. `source .env && mix phx.server`).
# Note: env var is DATBASE_URL (matching the .env file spelling).
turso_url = System.get_env("DATBASE_URL") || ""
turso_token = System.get_env("TURSO_TOKEN") || ""

if turso_url != "" do
  config :local_rag, :turso, url: turso_url, token: turso_token
end

if config_env() == :prod do
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"

  config :local_rag, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :local_rag, LocalRagWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [ip: {0, 0, 0, 0, 0, 0, 0, 0}],
    secret_key_base: secret_key_base
end

