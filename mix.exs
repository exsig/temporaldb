defmodule TemporalDB.Mixfile do
  use Mix.Project

  def project do
    [ app: :temporaldb,
      version: "0.0.1",
      elixir: "~> 0.10.2-dev",
      name: "TemporalDB",
      deps: deps,
      env: [prod: [default_root_dir: "/srv/exs/streams"],
            test: [default_root_dir: Path.expand(__DIR__) |> Path.join "test"],
            dev:  [default_root_dir: Path.expand(__DIR__)]]
    ]
  end

  def application, do: []

  defp deps do
    [
      {:hanoidb, github: "josephwecker/hanoidb", branch: "minimal"}
    ]
  end
end
