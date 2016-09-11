defmodule WorldTest do
  use ExUnit.Case, async: true

  alias Turtles.World

  @size {100, 100}

  setup do
    {:ok, world} = World.start_link(@size)
    [world: world]
  end

  test "begins with a full world clear", %{world: world} do
    all_locations =
      for x <- 0..(elem(@size, 0) - 1), y <- 0..(elem(@size, 1) - 1) do
        {x, y}
      end
    assert World.clear_changes(world) == all_locations
  end

  test "begins with no plant changes", %{world: world} do
    assert World.plant_changes(world) == []
  end

  test "begins with no turtle changes", %{world: world} do
    assert World.turtle_changes(world) == []
  end

  test "records plant placements", %{world: world} do
    World.place_plants(world, [{0, 0}, {50, 50}])
    assert World.plant_changes(world) == [{0, 0}, {50, 50}]
  end

  test "records turtle placements", %{world: world} do
    World.place_turtles(world, [{0, 0}, {50, 50}])
    assert World.turtle_changes(world) == [{0, 0}, {50, 50}]
  end

  test "turtles will eat if food is available", %{world: world} do
    World.place_plants(world, [{0, 0}])
    World.place_turtles(world, [{0, 0}])
    World.changes(world)

    assert World.eat_or_move(world, {0, 0}, {1, 0}) == :ate
    assert World.changes(world) == [{:clear, {0, 0}}, {:turtle, {0, 0}}]
  end

  test "turtles will move if no food is available and location is open",
       %{world: world} do
    World.place_turtles(world, [{0, 0}])
    World.changes(world)

    assert World.eat_or_move(world, {0, 0}, {1, 0}) == :moved
    assert World.changes(world) == [{:clear, {0, 0}}, {:turtle, {1, 0}}]
  end

  test "turtles will pass if they can't eat or move", %{world: world} do
    World.place_turtles(world, [{0, 0}, {1, 0}])
    World.changes(world)

    assert World.eat_or_move(world, {0, 0}, {1, 0}) == :pass
    assert World.changes(world) == World.Changes.empty
  end

  test "turtles will not die if food is available", %{world: world} do
    World.place_plants(world, [{0, 0}])
    World.place_turtles(world, [{0, 0}])
    World.changes(world)

    assert World.eat_or_die(world, {0, 0}) == :ate
    assert World.changes(world) == [{:clear, {0, 0}}, {:turtle, {0, 0}}]
  end

  test "turtles will die if no food is available", %{world: world} do
    World.place_turtles(world, [{0, 0}])
    World.changes(world)

    assert World.eat_or_die(world, {0, 0}) == :died
    assert World.changes(world) == [{:clear, {0, 0}}]
  end

  test "turtles can give birth on open locations", %{world: world} do
    World.place_turtles(world, [{0, 0}])
    World.changes(world)

    assert World.give_birth(world, {1, 0}) == :birthed
    assert World.changes(world) == [{:turtle, {1, 0}}]
  end

  test "turtles pass if they can't give birth", %{world: world} do
    World.place_turtles(world, [{0, 0}, {1, 0}])
    World.changes(world)

    assert World.give_birth(world, {1, 0}) == :pass
    assert World.changes(world) == World.Changes.empty
  end

  test "clears changes as they are fetched", %{world: world} do
    assert World.changes(world) != World.Changes.empty
    assert World.changes(world) == World.Changes.empty
  end
end
