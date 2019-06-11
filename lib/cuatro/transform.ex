defmodule Cuatro.Transform do
  use Toml.Transform
  
  def transform(:family, v) when is_binary(v) do
    String.to_atom(v)
  end
  def transform(_k, v), do: v
end
