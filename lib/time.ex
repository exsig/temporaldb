defmodule Time do
  # TODO: Find out if the now_dt is an epoch from year 0 or 1970 and adjust logic appropriately

  # See: https://gist.github.com/zaphar/104903
  # See:

  @type year       :: non_neg_integer
  @type month      :: 1..12
  @type day        :: 1..31
  @type hour       :: 0..23
  @type minute     :: 0..59
  @type second     :: 0..59
  @type daynum     :: 1..7
  @type weeknum    :: 1..53
  @type megasecs   :: non_neg_integer
  @type secs       :: non_neg_integer
  @type microsecs  :: non_neg_integer

  @type e_date     :: {year, month, day}
  @type e_time     :: {hour, minute, second} # erlang time

  #--------- DateTime types --------------------------------------------------
  @type erl_dt         :: {e_date, e_time}            # erlang datetime tuple (NOTE: No fractions of a second)
  @type now_dt         :: {megasecs, secs, microsecs} # erlang timestamp tuple such as returned by :erlang.now()
  @type unix_dt        :: non_neg_integer             # unix epoch            (NOTE: Also no fractions of a second)
  @type micro_dt       :: non_neg_integer             # microtime integer
  @type unixhighres_dt :: float                       # unix epoch as float with microtime
  @type bin_dt         :: <<_ :: 8 * 8>>              # 64 bit binary representation of the micro_dt


  @gregorian_seconds_1970 62_167_219_200 # == :calendar.datetime_to_gregorian_seconds({{1970,1,1},{0,0,0}})

  def now(),                     do: :erlang.now()

  def timestamp_to_datetime(ts), do: :calendar.now_to_datetime(ts)
  def datetime_to_timestamp(dt)  do
    gseconds = :calendar.datetime_to_gregorian_seconds(dt)
    eseconds = gseconds - @gregorian_seconds_1970
    {div(eseconds, 1_000_000), rem(eseconds, 1_000_000), 0}
  end

  @doc "64-bit (native-endian) binary representation of the microtime, from various formats"
  def microtime(year,month,day,hour),                    do: microtime({{year,month,day},{hour,0,0}})
  def microtime({year,month,day,hour}),                  do: microtime({{year,month,day},{hour,0,0}})
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
