defmodule TemporalDB.Mixfile do
  use Mix.Project

  def project do
    [ app: :temporaldb,
      version: "0.0.1",
      elixir: "~> 0.10.2-dev",
      name: "TemporalDB",
      deps: deps ]
  end

  def application, do: []

  defp deps do
    [
      {:hanoidb, github: "josephwecker/hanoidb", branch: "minimal"}
    ]
  end
end
