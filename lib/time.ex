defmodule Time do
  @gregorian_seconds_1970 62_167_219_200 # == :calendar.datetime_to_gregorian_seconds({{1970,1,1},{0,0,0}})

  def now do: :erlang.now()
  def timestamp_to_datetime(ts), do: :calendar.now_to_datetime(ts)
  def datetime_to_timestamp(dt) do
    gseconds = :calendar.datetime_to_gregorian_seconds(dt)
    eseconds = gseconds - @gregorian_seconds_1970
    {div(eseconds, 1_000_000), rem(eseconds, 1_000_000), 0}
  end

  #def rfc_1123
  #def rfc_822
  #def iso_8601
end
