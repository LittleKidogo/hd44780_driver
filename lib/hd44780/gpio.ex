defmodule Hdd4780.GPIO do
  @moduledoc """
  This module holds the process implementation that holds the state when using `GPIO`
  to communicate with the LCD Matrix Screen. Implemented as GenServer this module holds
  in its state
  1. A map of references for the connections to the pins and the number of rows and colums a screen has.
  2. A list of keys for various settings such as direction of input, scrolling effect, a flag stating the
  screen's current operation, the current fontface the screen is utilizing.

  In addition to holding this state this GenServer exposes calls to let a user perform various actions such as
  writing to the screen, blinking the cursor, moving the cursor on the screen, turing the display on and off
  """

  use GenServer
  alias Circuits.GPIO

  defmodule State do
   @moduledoc """
    Holds a data structure to represent the state of the LCD Driver, this holds the following keys

    * pins - a map holding references for the connections to various pins used when communicating
    with the LCD Screen
    """
    @type t :: %__MODULE__{}
   defstruct [:pins, :font, :lines, :cols, :direction]
  end

  @spec start_link(list()) :: {:ok, pid}
  def start_link(%{name: name} = config) do
    GenServer.start_link(__MODULE__, config, [name: name])
  end

  @spec init(map()) :: {:ok, State.t()} | {:error, term()}
  def init(%{pins: %{en: en, rs: rs, d4: d4, d5: d5, d6: d6, d7: d7}} = config) do
    with {:ok, pins} <- open_pins(),
         new_state <- %State{pins: pins},
         {:ok, state = %State{}} <- function_set(config)
    do
      {:ok, state}
    else
      val ->
        val
    end
  end

  @doc false
  # this function runs an initalizization sequence the LCD Driver
  # - in the future this needs to be modified to allow for 8 bit or 4 bit initialization
  @spec initialize() :: {:ok, State.t()} | {:error, term()}

  @doc false
  # this function runs a function set to initialize the following
  # - input direction
  # - display on/off
  # - interface length
  @spec function_set(%{required(:font, :lines, :cols, :direction)}, State.t()} :: {:ok, State.t()} | {:error, term()}
  def function_set(%{font: f, lines: l, cols: c, direction: d}, %{pins: %{rs: rs, d4: d4, d5: d5, d6: d6, d7: d7} = state) do
    with :ok <- GPIO.write(rs, 0),
         {:ok, :written} <- write_byte(0, state) do
           {:ok, %{ state | font: f, lines: l, cols: c, direction: d}}
    else
     val ->
       {:error, val}
    end
  end


  @doc false
  # this function writes a byte to the LCD Display
  # In the future this needs to be modified to check the state for 8 bit or
  # 4 bit mode and use the appropriate pins in regards to this setting
  @spec write_byte(byte(), State.t(), non_negative_integer()) :: {:ok, :written} | {:error, term()}
  def write_byte(byte, %{pins: pins}, rs)  do
    write_4_bits(byte >>> 4, rs)
    write_4_bits(btye, rs)
  end

  @doc false
  # this function writes to the device when in 4 bit mode
  @spec write_4_bits(bitstring(), State.t(), non_negative_integer) :: {:ok, :written} | {:error, term()}
  def write_4_bits(bits, %{pins: %{d4: d4, d5: d5, d6: d6, d7: d7} = state, rs) do
    with :ok <- GPIO.write(rs, rs),
         :ok <- GPIO.write(d4, bits &&& 0x01),
         :ok <- GPIO.write(d5, bits >>> 1 &&& 0x01),
         :ok <- GPIO.write(d6, bits >>> 2 &&& 0x01),
         :ok <- GPIO.write(d7, bits >>> 3 &&& 0x01),
         {:ok, _} <- pulse_en(state)
    do
      {:ok, :written}
    else
      val -> {:error, val}
    end
  end

  @doc false
  # this functions opens pins when the server is starting up
  @spec open_pins(%{required(:en, :rs, :d4, :d5, :d6, :d7)}) :: {:ok, map()} | {:error, term()}
  def open_pins(%{en: en, rs: rs, d4: d4, d5: d5, d6: d6, d7: d7}) do
    with {:ok, enpin} <- GPIO.open(en, :both),
         {:ok, rspin} <- GPIO.open(rs, :both),
         {:ok, d4pin} <- GPIO.open(d4, :both),
         {:ok, d5pin} <- GPIO.open(d5, :both),
         {:ok, d6pin} <- GPIO.open(d6, :both),
         {:ok, d7pin} <- GPIO.open(d7, :both)
    do
      {:ok, %{en: enpin, rs: rspin, d4: d4pin, d5: d5pin, d6: d6pin, d7: d7pin}}
    else
      {:error, msg} ->
          {:error, msg}
    end
  end



  @doc false
  # this function causes a rising edge in th en pin to indicate a command
  @spec pulse_en(State.t()) :: {:ok, State.t()} | {:error, term()}
  defp pulse(%{pins: %{en: en} = state) do

    with :ok <- GPIO.write(en, 0),
         :ok <- GPIO.write(en, 1),
         :ok <- GPIO.write(en, 0)
    do
      {:ok , state}
    end
  end


end
