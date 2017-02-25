defmodule Ginseng.Worker do
  use GenServer
  alias :mnesia, as: Mnesia

  # Start/stop
  def start() do
    GenServer.start_link(__MODULE__, [])
  end

  def stop() do
    GenServer.cast(__MODULE__, :stop)
  end

  # Functional Inteface

  def put(key, value) do
    GenServer.call(__MODULE__, {:put, key, value})
  end

  def get(key) do
    GenServer.call(__MODULE__, {:get, key})
  end

  def remove(key) do
    GenServer.call(__MODULE__, {:remove, key})
  end

  # Callback functions

  def init(_) do
    Application.start(Mnesia)
    Mnesia.wait_for_tables([:ginseng_cache], :infinity)
    {:ok, []}
  end

  def terminate(_reason, _state) do
    Application.stop(Mnesia)
  end

  def handle_cast(:stop, state) do
    {:stop, :normal, state}
  end

  def handle_call({:put, key, value}, _from, state) do
    record = {:ginseng_cache, key, value}
    data_to_write = fn() ->
      # Check to see what really comes out of reads and writes
      case Mnesia.read(:ginseng_cache, key) do
        [] ->
          Mnesia.write(record)
          nil
        #I think this is wrong.
        [{:ginseng_cache, old_value}] ->
            Mnesia.write(record)
            old_value
      end
    end

    {:atomic, result} = Mnesia.transaction(data_to_write)
    {:reply, result, state}
  end

  def handle_call({:get, key}, _from, state) do
    case Mnesia.dirty_read({:ginseng_cache, key}) do
      [{:ginseng_cache, value}] ->
        {:reply, value, []}
      _ ->
        {:reply, nil, state}
    end
  end

  def handle_call({:remove, key}, _from, state) do
    data_to_remove = fn() ->
      # Check to see what really comes out of reads and writes
      case Mnesia.read(:ginseng_cache, key) do
        [] ->
          nil
        [{:ginseng_cache, old_value}] ->
          Mnesia.delete({:ginseng_cache, key})
          value
      end
    end

    {:atomic, result} = Mnesia.transaction(data_to_write)
    {:reply, result, state}
  end
end
