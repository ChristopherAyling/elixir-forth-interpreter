defmodule Forth.Evaluator do
  alias Forth.Interpreter.State
  alias Forth.Operator

  def evaluate(tokens) when is_list(tokens) do
    evaluate({tokens, [], State.new()})
  end

  def evaluate({[], stack, state}) do
    {:ok, {stack, state}}
  end

  def evaluate(
        {[{:conditional, {if_tokens, else_tokens}, _meta} | tokens], [bool | stack], state}
      ) do
    chosen_tokens = if is_true?(bool), do: if_tokens, else: else_tokens

    with {:ok, {stack, state}} <- evaluate({chosen_tokens, stack, state}) do
      evaluate({tokens, stack, state})
    end
  end

  def evaluate({[{:new_word, {new_word_name, new_word_tokens}, _meta} | tokens], stack, state}) do
    state = State.add_word(state, new_word_name, new_word_tokens)
    evaluate({tokens, stack, state})
  end

  def evaluate({[{:dot_quote, string, _meta} | tokens], stack, state}) do
    IO.write(string)
    evaluate({tokens, stack, state})
  end

  def evaluate({[{:number, value, _meta} | tokens], stack, state}) do
    evaluate({tokens, [value | stack], state})
  end

  def evaluate({[{:do_loop, body_tokens, _meta} | tokens], stack, state}) do
    [until, from | stack] = stack
    state = State.loop_enter(state)

    body_evaluation =
      Enum.reduce_while(until..from, {:ok, {tokens, stack, state}}, fn i,
                                                                       {:ok,
                                                                        {tokens, stack, state}} ->
        case evaluate({body_tokens, [i | stack], state |> State.loop_step()}) do
          {:ok, {stack, state}} ->
            {:cont, {:ok, {tokens, stack, state}}}

          {:error, error} ->
            {:halt, {:error, error}}
        end
      end)

    case body_evaluation do
      {:ok, {tokens, stack, state}} ->
        state = State.loop_exit(state)
        evaluate({tokens, stack, state})

      {:error, error} ->
        {:error, error}
    end
  end

  def evaluate({[{:word, word_name, _meta} | tokens], stack, state}) do
    case Operator.op(word_name, {tokens, stack, state}) do
      {:ok, {tokens, stack, state}} ->
        evaluate({tokens, stack, state})

      {:error, :unknown_operator} ->
        with {:ok, word_tokens} <- State.fetch_word(state, word_name) do
          with {:ok, {stack, state}} <- evaluate({word_tokens, stack, state}) do
            evaluate({tokens, stack, state})
          end
        end
    end
  end

  # TODO loop

  defp is_true?(bool) do
    bool != 0
  end
end
