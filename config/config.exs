# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :local_rag,
  ecto_repos: [LocalRag.Repo],
  generators: [timestamp_type: :utc_datetime]

# RAG configuration – override in runtime.exs for production
# Using LM Studio (OpenAI-compatible API) at http://127.0.0.1:1234
config :local_rag, :rag,
  lm_studio_url: "http://127.0.0.1:1234",
  embedding_model: "text-embedding-bge-m3",
  # "local-model" routes to whichever chat/LLM model is currently loaded in LM Studio.
  # Replace with the exact API Model Identifier shown in LM Studio if you want to pin a specific model.
  generation_model: "google/gemma-4-e4b",
  embedding_dimensions: 1024,
  chunk_size: 500,
  chunk_overlap: 50,
  top_k: 5

# Configure the endpoint
config :local_rag, LocalRagWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: LocalRagWeb.ErrorHTML, json: LocalRagWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: LocalRag.PubSub,
  live_view: [signing_salt: "VFW44TqZ"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  local_rag: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.12",
  local_rag: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
