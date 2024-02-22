defmodule Forth.Operator do
  alias Forth.Interpreter.State

  def op("=", {tokens, [a, b | stack], state}) do
    value = if a == b, do: -1, else: 0
    {:ok, {tokens, [value | stack], state}}
  end

  def op("+", {tokens, [a, b | stack], state}) do
    {:ok, {tokens, [a + b | stack], state}}
  end

  def op("-", {tokens, [a, b | stack], state}) do
    {:ok, {tokens, [a - b | stack], state}}
  end

  def op("/", {tokens, [a, b | stack], state}) do
    {:ok, {tokens, [a / b | stack], state}}
  end

  def op("*", {tokens, [a, b | stack], state}) do
    {:ok, {tokens, [a * b | stack], state}}
  end

  def op("mod", {tokens, [a, b | stack], state}) do
    {:ok, {tokens, [rem(b, a) | stack], state}}
  end

  def op("<", {tokens, [a, b | stack], state}) do
    value = if a > b, do: -1, else: 0
    {:ok, {tokens, [value | stack], state}}
  end

  def op(">", {tokens, [a, b | stack], state}) do
    value = if a < b, do: -1, else: 0
    {:ok, {tokens, [value | stack], state}}
  end

  def op("swap", {tokens, [a, b | stack], state}) do
    {:ok, {tokens, [b, a | stack], state}}
  end

  def op(".", {tokens, [a | stack], state}) do
    IO.write("#{a} ")
    {:ok, {tokens, stack, state}}
  end

  def op("cr", {tokens, stack, state}) do
    IO.write("\n")
    {:ok, {tokens, stack, state}}
  end

  def op("emit", {tokens, [a | stack], state}) do
    IO.write(<<a::utf8>>)
    {:ok, {tokens, stack, state}}
  end

  def op("dup", {tokens, [a | stack], state}) do
    {:ok, {tokens, [a, a | stack], state}}
  end

  def op("drop", {tokens, [_a | stack], state}) do
    {:ok, {tokens, stack, state}}
  end

  def op("rot", {tokens, [a, b, c | stack], state}) do
    {:ok, {tokens, [c, a, b | stack], state}}
  end

  def op("over", {tokens, [a, b | stack], state}) do
    {:ok, {tokens, [b, a, b | stack], state}}
  end

  def op("i", {tokens, stack, state}) when length(state.loops) > 0 do
    loop_steps = State.loop_get_step(state)
    {:ok, {tokens, [loop_steps | stack], state}}
  end

  def op("and", {tokens, [a, b | stack], state}) do
    {:ok, {tokens, [b2i(i2b(a) and i2b(b)) | stack], state}}
  end

  def op("or", {tokens, [a, b | stack], state}) do
    {:ok, {tokens, [b2i(i2b(a) or i2b(b)) | stack], state}}
  end

  def op("invert", {tokens, [a | stack], state}) do
    val = if a == 0, do: -1, else: 0
    {:ok, {tokens, [val | stack], state}}
  end

  def op("variable", {tokens, stack, state}) do
    case tokens do
      [{:word, name, _} | rest] ->
        {:ok, {rest, stack, state |> State.add_var(name)}}

      _ ->
        {:error, :invalid_variable_declaration}
    end
  end

  def op(_, _) do
    {:error, :unknown_operator}
  end

  defp i2b(i) do
    i != 0
  end

  defp b2i(b) do
    if b, do: -1, else: 0
  end
end
