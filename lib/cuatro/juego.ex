defmodule Cuatro.Juego do
  use GenServer

  @vsn 3

  @moduledoc """
  El  juego de Conecta Cuatro es un juego donde dos
  jugadores deben insertar una pieza en una de las columnas.
  Esta pieza cae a modo de pila sobre las ya existentes o
  en la última posición y gana quien consigue conectar
  cuatro piezas de su mismo color.
  """

  defmodule Tablero do
    @moduledoc """
    Información del tablero. Nos da información del tamaño
    máximo del tablero, las columnas y las piezas ya
    insertadas así como de quién es el turno.
    """
    defstruct cols: [],
              turno: nil,
              jugadores: {nil, nil},
              num_jugadores: 0,
              ganador: nil
  end

  alias Cuatro.Juego.Tablero
  alias Cuatro.HiScore

  @jugador1 0
  @jugador2 1

  @max_x 7
  @max_y 6

  defp via(juego) do
    {:via, Registry, {Cuatro.Registry, juego}}
  end

  @doc "Inicia el juego"
  def start_link(juego) do
    GenServer.start_link __MODULE__, [], name: via(juego)
  end

  def stop(juego) do
    GenServer.stop via(juego)
  end

  @doc "Retorna información de quién es el siguiente"
  def who_plays?(juego) do
    GenServer.call via(juego), :quien_juega
  end

  def who_am_i?(juego) do
    GenServer.call via(juego), :quien_soy
  end

  def who_wins?(juego) do
    GenServer.call via(juego), :quien_gana
  end

  def sign_me_up(juego, jugador \\ nil) do
    GenServer.call via(juego), {:jugador, self(), jugador}
  end

  def exists?(juego) do
    case Registry.lookup(Cuatro.Registry, juego) do
      [{_pid, nil}] -> true
      [] -> false
    end
  end

  @doc "Inserta una ficha en el tablero"
  def insert(juego, col) when is_integer(col) and col >= 0 do
    GenServer.call via(juego), {:col, col}
  end

  def players(juego) do
    GenServer.call via(juego), :jugadores
  end

  @doc "Muestra las columnas"
  def show(juego) do
    GenServer.call via(juego), :muestra
  end

  @impl true
  def init([]) do
    cols = List.duplicate([], @max_x)
    {:ok, %Tablero{cols: cols,
                   turno: @jugador1}}
  end

  defp cambia_turno(@jugador1), do: @jugador2
  defp cambia_turno(@jugador2), do: @jugador1

  defp agrega_jugador(tablero, id, name) do
    jugadores = case tablero.jugadores do
      {nil, id2} -> {{id, name || "Rojo"}, id2}
      {id2, nil} -> {id2, {id, name || "Amarillo"}}
    end
    num_jugadores = tablero.num_jugadores + 1
    %Tablero{tablero | jugadores: jugadores,
                       num_jugadores: num_jugadores}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, id, _reason},
                  tablero) do
    num = tablero.num_jugadores - 1
    case tablero.jugadores do
      {{^id, _}, id2} ->
        {:noreply, %Tablero{tablero | jugadores: {nil, id2},
                                      num_jugadores: num}}
      {id2, {^id, _}} ->
        {:noreply, %Tablero{tablero | jugadores: {id2, nil},
                                      num_jugadores: num}}
    end
  end

  @impl true
  def handle_call(:quien_gana, _from, tablero) do
    {:reply, tablero.ganador, tablero}
  end

  def handle_call(:quien_soy, {pid, _} = _from, tablero) do
    reply = case tablero.jugadores do
      {{^pid, _}, _} -> 0;
      {_, {^pid, _}} -> 1
      {nil, nil} -> :esperando_jugadores
    end
    {:reply, reply, tablero}
  end

  @impl true
  def handle_call(:jugadores, _from, tablero) do
    {jugador1, jugador2} = tablero.jugadores
    {:reply, [get_player_id(jugador1), get_player_id(jugador2)], tablero}
  end

  @impl true
  def handle_call({:jugador, id, name}, _from, tablero) do
    Process.monitor id
    case tablero.jugadores do
      {_, {^id, _}} -> {:reply, @jugador1, tablero}
      {{^id, _}, _} -> {:reply, @jugador2, tablero}
      {nil, _} ->
          {:reply, @jugador1, agrega_jugador(tablero, id, name)}
      {_, nil} ->
          {:reply, @jugador2, agrega_jugador(tablero, id, name)}
      _ ->
          {:reply, :partida_ocupada, tablero}
    end
  end

  @impl true
  def handle_call(_msg, _from,
                  %Tablero{num_jugadores: num} = tablero)
                    when num < 2 do
    {:reply, :esperando_jugadores, tablero}
  end

  @impl true
  def handle_call(:quien_juega, _from, tablero) do
    {:reply, tablero.turno, tablero}
  end

  @impl true
  def handle_call({:col, ix}, {pid, _},
                  %Tablero{jugadores: {_, {pid, _}},
                           turno: @jugador2} = tablero)
                    when ix >= 0 and ix < @max_x do
    juega(ix, tablero)
  end

  @impl true
  def handle_call({:col, ix}, {pid, _},
                  %Tablero{jugadores: {{pid, _}, _},
                           turno: @jugador1} = tablero)
                    when ix >= 0 and ix < @max_x do
    juega(ix, tablero)
  end

  @impl true
  def handle_call({:col, _ix}, _from, tablero) do
    {:reply, :turno_de_otro, tablero}
  end

  @impl true
  def handle_call(:muestra, _from, tablero) do
    cols = tablero.cols
           |> Enum.map(&normaliza/1)
    {:reply, cols, tablero}
  end

  @impl true
  def code_change(2, %Tablero{jugadores: {pid1, pid2}} = tablero, _extra) do
    pid1 = case pid1 do
      nil -> nil
      _ -> {pid1, "Rojo"}
    end
    pid2 = case pid2 do
      nil -> nil
      _ -> {pid2, "Amarillo"}
    end
    {:ok, %Tablero{tablero | jugadores: {pid1, pid2}}}
  end
  def code_change(1, tablero, _extra) do
    Enum.each Cuatro.Application.children(),
              &(Supervisor.start_child Cuatro.Supervisor, &1)

    Registry.register Cuatro.Registry, "legacy", nil
    {:ok, tablero}
  end

  defp get_player_id({id, _}), do: id
  defp get_player_id(nil), do: nil

  defp add_score(%Tablero{jugadores: {{_, name1}, {_, name2}}}, 1) do
    HiScore.add_score_for name1, 1
    HiScore.add_score_for name2, 1
  end
  defp add_score(%Tablero{turno: 0, jugadores: {{_, name}, _}}, 2) do
    HiScore.add_score_for name, 2
  end
  defp add_score(%Tablero{turno: 1, jugadores: {_, {_, name}}}, 2) do
    HiScore.add_score_for name, 2
  end

  defp juega(ix, tablero) do
    col = Enum.at(tablero.cols, ix)
    if length(col) < @max_y do
      col = col ++ [tablero.turno]
      cols = List.replace_at(tablero.cols, ix, col)
      tablero = %Tablero{tablero | cols: cols}
      if gana?(tablero) do
        add_score(tablero, 2)
        {:reply, {:gana, tablero.turno},
                 %Tablero{tablero | ganador: tablero.turno}}
      else
        if lleno?(tablero) do
          add_score(tablero, 1)
          {:reply, :lleno, tablero}
        else
          turno = cambia_turno(tablero.turno)
          {:reply, :sigue, %Tablero{tablero | turno: turno}}
        end
      end
    else
      {:reply, :col_llena, tablero}
    end
  end

  defp normaliza(col) when length(col) == @max_y, do: col
  defp normaliza(col) when length(col) < @max_y do
    normaliza(col ++ [nil])
  end

  defp lleno?(tablero) do
    Enum.all? tablero.cols, &(length(&1) == @max_y)
  end

  defp gana?(tablero) do
    f = fn({inc_x, inc_y}, {pos_x, pos_y}) ->
      comprueba(tablero, pos_x, pos_y, inc_x, inc_y, 4)
    end
    paths = [{-1, -1}, {-1, 0}, {-1, 1},
             {0, -1}, {0, 1},
             {1, -1}, {1, 0}, {1, 1}]
    for(pos_x <- 0..(@max_x - 1),
        pos_y <- 0..(@max_y - 1),
        do: {pos_x, pos_y})
    |> Enum.any?(fn(pos) ->
                   Enum.any?(paths, &(f.(&1, pos)))
                 end)
  end

  defp comprueba(_tablero, _pos_x, _pos_y,
                 _inc_x, _inc_y, 0), do: true
  defp comprueba(_tablero, pos_x, pos_y, _inc_x, _inc_y, _i)
                  when pos_x < 0 or
                       pos_y < 0 or
                       pos_x >= @max_x or
                       pos_y >= @max_y, do: false
  defp comprueba(tablero, pos_x, pos_y, inc_x, inc_y, i) do
    if coord(tablero, pos_x, pos_y) == tablero.turno do
      comprueba(tablero, pos_x + inc_x, pos_y + inc_y,
                inc_x, inc_y, i - 1)
    else
      false
    end
  end

  defp coord(tablero, x, y) do
    tablero.cols
    |> Enum.at(x)
    |> Enum.at(y)
  end
end
