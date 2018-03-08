defmodule Ginseng.Worker do
  use GenServer
  alias :mnesia, as: Mnesia

  # Start/stop
  def start_link() do
    GenServer.start_link(__MODULE__, [], name: :cache)
  end

  def stop() do
    GenServer.stop(:cache)
  end

  # Functional Inteface

  def put(key, value) do
    GenServer.call(:cache, {:put, key, value})
  end

  def get(key) do
    case Mnesia.dirty_read({:ginseng_cache, key}) do
      [{:ginseng_cache, _key, value}] -> value
      _ -> nil
    end
  end

  def remove(key) do
    GenServer.call(:cache, {:remove, key})
  end

  # Callback functions

  def init(_) do
    Mnesia.create_schema(node_list())
    Mnesia.start
    Mnesia.create_table(:ginseng_cache, [attributes: [:key, :value]])
    {:ok, []}
  end

  def terminate(_reason, _state) do
    Mnesia.stop
  end

  def handle_cast(:stop, state) do
    {:stop, :normal, state}
  end

  def handle_call({:put, key, value}, _from, state) do
    record = {:ginseng_cache, key, value}
    data_to_write = fn() ->
      Mnesia.write(record)
      value
    end

    {:atomic, result} = Mnesia.transaction(data_to_write)
    {:reply, result, state}
  end

  def handle_call({:remove, key}, _from, state) do
    data_to_remove = fn() ->
      case Mnesia.read(:ginseng_cache, key) do
        [] ->
          nil
        [{:ginseng_cache, key, value}] ->
          Mnesia.delete({:ginseng_cache, key})
          value
      end
    end

    {:atomic, result} = Mnesia.transaction(data_to_remove)
    {:reply, result, state}
  end

  defp node_list do
    case Application.get_env(:ginseng, :nodelist) do
      nil       -> node()
      node_list -> node_list
    end
  end
end
