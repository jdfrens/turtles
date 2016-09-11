defmodule Turtles.World do
  defmodule Changes do
    def clear(changes, location) do
      [{:clear, location} | changes]
    end

    def plant(changes, location) do
      [{:plant, location} | changes]
    end

    def turtle(changes, location) do
      [{:turtle, location} | changes]
    end

    def empty do
      []
    end
  end

  defstruct size: nil,
            plants: MapSet.new,
            turtles: MapSet.new,
            changes: Changes.empty

  # Client API

  def start_link(size, options \\ [ ]) do
    Agent.start_link(fn -> init(size) end, options)
  end

  def changes(world) do
    Agent.get_and_update(world, &handle_changes/1)
  end

  #
  # locations is a list of x, y tuples:
  #
  #     [{0, 0}, {0, 1}, …]
  #
  def place_plants(world, locations) do
    Agent.update(world, fn struct -> handle_place_plants(struct, locations) end)
  end

  #
  # locations is a list of x, y tuples:
  #
  #     [{0, 0}, {0, 1}, …]
  #
  def place_turtles(world, locations) do
    Agent.update(world, fn struct -> handle_place_turtles(struct, locations) end)
  end

  def eat_or_move(world, location, move_location) do
    Agent.get_and_update(world, fn struct ->
      handle_eat_or_move(struct, location, move_location)
    end)
  end

  def eat_or_die(world, location) do
    Agent.get_and_update(world, fn struct ->
      handle_eat_or_die(struct, location)
    end)
  end

  def give_birth(world, new_location) do
    Agent.get_and_update(world, fn struct ->
      handle_give_birth(struct, new_location)
    end)
  end

  # Server API

  defp init(size = {width, height}) do
    background = for x <- 0..(width - 1), y <- 0..(height - 1), do: {x, y}
    changes = Enum.reduce(background, Changes.empty, &Changes.clear(&2,&1))
    %__MODULE__{size: size, changes: changes}
  end

  defp handle_changes(world = %__MODULE__{changes: changes}) do
    {Enum.reverse(changes), %__MODULE__{world | changes: Changes.empty}}
  end

  defp handle_place_plants(
    world = %__MODULE__{plants: plants, changes: changes},
    locations
  ) do
    unique_locations = MapSet.new(locations)
    new_plants = MapSet.union(plants, unique_locations)
    new_changes = Enum.reduce(unique_locations, changes, &Changes.plant(&2, &1))
    %__MODULE__{world | plants: new_plants, changes: new_changes}
  end

  defp handle_place_turtles(
    world = %__MODULE__{turtles: turtles, changes: changes},
    locations
  ) do
    unique_locations = MapSet.new(locations)
    new_turtles = MapSet.union(turtles, unique_locations)
    new_changes = Enum.reduce(unique_locations, changes, &Changes.turtle(&2, &1))
    %__MODULE__{world | turtles: new_turtles, changes: new_changes}
  end

  defp handle_eat_or_move(
    world = %__MODULE__{plants: plants, turtles: turtles, changes: changes},
    location,
    move_location
  ) do
    cond do
      MapSet.member?(plants, location) ->
        eat(world, location)
      not MapSet.member?(turtles, move_location) ->
        new_turtles =
          MapSet.delete(turtles, location)
          |> MapSet.put(move_location)
        new_changes =
          changes
          |> Changes.clear(location)
          |> Changes.turtle(move_location)
        {:moved, %__MODULE__{world | turtles: new_turtles, changes: new_changes}}
      true ->
        {:pass, world}
    end
  end

  defp handle_eat_or_die(
    world = %__MODULE__{plants: plants, turtles: turtles, changes: changes},
    location
  ) do
    cond do
      MapSet.member?(plants, location) ->
        eat(world, location)
      true ->
        new_turtles = MapSet.delete(turtles, location)
        new_changes = changes |> Changes.clear(location)
        {:died, %__MODULE__{world | turtles: new_turtles, changes: new_changes}}
    end
  end

  defp handle_give_birth(
    world = %__MODULE__{turtles: turtles, changes: changes},
    new_location
  ) do
    if not MapSet.member?(turtles, new_location) do
      new_turtles = MapSet.put(turtles, new_location)
      new_changes = [{:turtle, new_location} | changes]
      {:birthed, %__MODULE__{world | turtles: new_turtles, changes: new_changes}}
    else
      {:pass, world}
    end
  end

  ## Debugging-ish

  def clear_changes(world) do
    filter_changes(world, :clear)
  end

  def plant_changes(world) do
    filter_changes(world, :plant)
  end

  def turtle_changes(world) do
    filter_changes(world, :turtle)
  end

  defp filter_changes(world, type) do
    world
    |> changes
    |> Enum.filter(fn {t, _} -> t == type end)
    |> Enum.map(&elem(&1,1))
  end

  # Helpers

  defp eat(world = %__MODULE__{plants: plants, changes: changes}, location) do
    new_plants = MapSet.delete(plants, location)
    new_changes =
      changes
      |> Changes.clear(location)
      |> Changes.turtle(location)
    {:ate, %__MODULE__{world | plants: new_plants, changes: new_changes}}
  end
end
