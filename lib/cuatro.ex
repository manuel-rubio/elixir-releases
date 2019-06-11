defmodule Cuatro do
  require Logger
  alias Cuatro.{Juego, HiScore}

  @player1 0
  @player2 1

  @player1_symbol IO.ANSI.format(["[", :red_background,
                                  "O", :reset,
                                  "]"])
  @player2_symbol IO.ANSI.format(["[", :yellow_background, :black,
                                  "O", :reset,
                                  "]"])
  @nojugado_symbol IO.ANSI.format(["[ ]"])

  @player1_color "red"
  @player2_color "yellow"

  @msg_winner "You win !!!"
  @msg_looser "You loose :-("
  @msg_waiting "waiting for players, sign up!"
  @msg_other_player_turn "it's the other player turn... please wait"
  @msg_col_full "column full, try another one"
  @msg_err_busy "error: busy match"
  @msg_playing_as "playing as"

  @legacy_game_name "legacy"

  defp show_all do
    Juego.players(@legacy_game_name)
    |> Enum.each(fn(jugador) ->
                   info = Process.info(jugador)
                   show(info[:group_leader])
                 end)
  end

  defp show_to(jugador, msg) do
    leader = Process.info(jugador)[:group_leader]
    IO.puts(leader, msg)
  end

  @doc """
       Realiza el movimiento y retorna el estado, si ha
       ganado muestra el tablero y detiene el juego.
       """
  def move(col) do
    case Juego.insert(@legacy_game_name, col) do
      {:gana, quien} ->
        [ganador, perdedor] = case quien do
          @player1 -> Juego.players(@legacy_game_name)
          @player2 -> Enum.reverse Juego.players(@legacy_game_name)
        end
        show_all()
        show_to ganador, @msg_winner
        show_to perdedor, @msg_looser
        Juego.stop(@legacy_game_name)
      :esperando_jugadores ->
        IO.puts @msg_waiting
      :sigue ->
        show_all()
      :turno_de_otro ->
        IO.puts @msg_other_player_turn
        :ok
      :col_llena ->
        IO.puts @msg_col_full
        :ok
    end
  end

  defp color(@player1), do: @player1_color
  defp color(@player2), do: @player2_color

  def sign_me_up do
    if not Juego.exists?(@legacy_game_name) do
      Juego.start(@legacy_game_name)
    end
    case Juego.sign_me_up(@legacy_game_name) do
      :partida_ocupada ->
        IO.puts @msg_err_busy
      jugador ->
        IO.puts "#{@msg_playing_as} #{color(jugador)}"
    end
  end

  defp symbol(@player1), do: @player1_symbol
  defp symbol(@player2), do: @player2_symbol
  defp symbol(nil), do: @nojugado_symbol

  defp traduce_symbols(col) do
    col
    |> Enum.map(&symbol/1)
    |> Enum.join()
  end

  defp traspone([[]|_]), do: []
  defp traspone(matriz) do
    [ Enum.map(matriz, &hd/1) |
      traspone(Enum.map(matriz, &tl/1)) ]
  end

  @doc "Muestra el tablero"
  def show(device \\ :stdio) do
    cols = Juego.show(@legacy_game_name)
    imprime = &(IO.puts(device, &1))

    cols
    |> Enum.map(&Enum.reverse/1)
    |> traspone()
    |> Enum.map(&traduce_symbols/1)
    |> Enum.join("\n")
    |> imprime.()

    for(i <- 0..(length(cols) - 1),
      do: if(i<10, do: " #{i} ", else: "#{i} "))
    |> Enum.join()
    |> imprime.()
  end

  def top_list do
    top_list = HiScore.top_list()
    :io.format("~-20s Points\n", ["Name"])
    IO.puts(String.duplicate("-", 20) <> " " <> String.duplicate("-", 6))
    for hscore <- top_list do
      :io_lib.format("~-20s ~6b\n", [hscore.name, hscore.score])
    end
    |> IO.puts()
  end

end
