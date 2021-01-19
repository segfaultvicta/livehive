# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

# Configures the endpoint
config :livehive, LivehiveWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "pcW2UrAFM5NXhR8mJT0aY2GjJ7iWMUoUFK2Xu3m9fjzt5f1oIb0qHQhwz/yGSL0B",
  render_errors: [view: LivehiveWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Livehive.PubSub,
  live_view: [signing_salt: "mzEU9QDg"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"

config :livehive, :adjectives, ~w(
	shiny brilliant dusty sparkly polished amused boiling brave breezy bumpy careful charming courageous
	defiant delightful determined elated energetic exuberant faithful fantastic fierce fluffy friendly
	fuzzy gentle harmonious helpful hollow hungry jolly lively lucky magnificent magnanimous melodic
	melting miniature quaint quick rapid relieved resonant roasted responsible shaggy shivering splendid
	stupendous tangy thoughtful thundering victorious vivacious whimsical whispering zesty
)

config :livehive, :nouns, ~w(
	armadillo pangolin teacup treehouse clavichord clover hurricane furball windowsill mountaintop
	leopard elephant gopher python camel windmill skyscraper shoelace matchstick snurble leaf willow
	panther tiger lion timberwolf teapot paintbrush tapestry spatula orchestra thimble harpsichord goose
)

config :livehive, :happy_sentiments, ["happy"]

config :livehive, :sad_sentiments, ["sad", "hardno"]

config :livehive, :blocking_sentiments, ["question", "order", "hand", "hardno"]
