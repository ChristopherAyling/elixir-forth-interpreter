defmodule Forth.Interpreter.State do
  defstruct words: %{}, loops: [], vars: %{}

  def new() do
    %__MODULE__{}
  end

  def add_word(state, name, tokens) do
    %{state | words: Map.put(state.words, name, tokens)}
  end

  def fetch_word(state, name) do
    case Map.fetch(state.words, name) do
      {:ok, word_tokens} -> {:ok, word_tokens}
      :error -> {:error, {:undefined_word, name}}
    end
  end

  def loop_enter(state) do
    %{state | loops: [%{steps: 0} | state.loops]}
  end

  def loop_exit(state) do
    %{state | loops: tl(state.loops)}
  end

  def loop_step(state) do
    [loop | loops] = state.loops
    %{state | loops: [%{loop | steps: loop.steps + 1} | loops]}
  end

  def loop_get_step(state) do
    state.loops |> hd |> Map.fetch!(:steps)
  end

  def add_var(state, name) do
    %{state | vars: Map.put(state.vars, name, :uninitialised)}
  end

  def set_var(state, name, value) do
    %{state | vars: Map.put(state.vars, name, value)}
  end

  def fetch_var(state, name) do
    case Map.fetch(state.vars, name) do
      {:ok, value} -> {:ok, value}
      :error -> {:error, {:undefined_var, name}}
    end
  end
end
