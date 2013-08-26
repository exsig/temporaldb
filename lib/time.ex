defmodule Time do
  @gregorian_seconds_1970 62_167_219_200 # == :calendar.datetime_to_gregorian_seconds({{1970,1,1},{0,0,0}})

  def now(),                     do: :erlang.now()
  def timestamp_to_datetime(ts), do: :calendar.now_to_datetime(ts)
  def datetime_to_timestamp(dt)  do
    gseconds = :calendar.datetime_to_gregorian_seconds(dt)
    eseconds = gseconds - @gregorian_seconds_1970
    {div(eseconds, 1_000_000), rem(eseconds, 1_000_000), 0}
  end

  @doc "64-bit (native-endian) binary representation of the microtime, from various formats"
  def microtime(dt = {{_,_,_},{_,_,_}}),                 do: microtime(datetime_to_timestamp(dt))
  def microtime({mega, secs, micro}),                    do: mega * 1_000_000_000_000 + secs * 1_000_000 + micro
  def microtime(<<ts::64>>),                             do: ts
  def microtime(ts) when is_binary(ts),                  do: microtime(ts|>String.to_float|>elem(0))
  def microtime(ts) when is_integer(ts) and ts < 1.0e10, do: ts * 1_000_000
  def microtime(ts) when is_integer(ts),                 do: ts
  def microtime(ts) when is_float(ts) and ts < 1.0e10,   do: round(ts*1_000_000)
  def microtime(ts) when is_float(ts),                   do: round(ts)

  def microtime64(ts=<<t::64>>), do: ts
  def microtime64(ts),           do: <<(microtime(ts))::64>>

  #def rfc_1123
  #def rfc_822
  #def iso_8601
end
