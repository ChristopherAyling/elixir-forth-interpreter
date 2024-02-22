defmodule Forth do
  alias Forth.Tokeniser
  alias Forth.Interpreter.State

  defp stdlib_code() do
    """
    ( begin stdlib )
    : cr 10 emit ;
    : say-hello ( -- ) 111 108 108 101 72 emit emit emit emit emit cr ;

    : always-neg dup dup * / ;
    : is-positive dup dup neg + 0 = ;

    : print dup . cr;
    ( end stdlib )

    ( begin main )
    """
  end

  defp load_stdlib() do
    with {:ok, tokens} <- Tokeniser.tokenize(stdlib_code(), "stdlib.f"),
         {:ok, {_stack, state}} <- evaluate_tokens(tokens, [], State.new()) do
      {:ok, state}
    end
  end

  def run_text(content, file_path) do
    with {:ok, stdlib_state} <- load_stdlib(),
         {:ok, tokens} <- Tokeniser.tokenize(content, file_path),
         {:ok, {stack, state}} <- evaluate_tokens(tokens, [], stdlib_state) do
      # IO.puts("Success!")
      # IO.inspect(stack)
      # IO.inspect(stack, [charlists: :as_lists])
      {:ok, {stack, state}}
    else
      {:error, reason} ->
        IO.puts("Error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def run_file(file_path) do
    content = File.read!(file_path)
    run_text(content, file_path)
  end

  def run() do
    with {:ok, tokens} <- Tokeniser.tokenize(stdlib_code(), "stdlib.f"),
         {:ok, {stack, state}} <- evaluate_tokens(tokens, [], State.new()) do
      loop(stack, state)
    end
  end

  defp loop(stack, state) do
    input = IO.gets("forth> ") |> String.trim()

    {:ok, {stack, state}} = interpret(input, stack, state)
    # IO.inspect("stack: #{inspect(Enum.reverse(stack), charlists: :as_lists)}")
    # IO.puts("state: #{inspect(state)}")

    loop(stack, state)
  end

  def interpret(text, stack, state) do
    with {:ok, tokens} <- Tokeniser.tokenize(text) do
      case evaluate_tokens(tokens, stack, state) do
        {:error, reason} ->
          IO.puts("Error: #{inspect(reason)}")
          {:ok, {stack, state}}

        {:ok, {stack, state}} ->
          {:ok, {stack, state}}
      end
    else
      {:error, reason} ->
        IO.puts("Error: #{inspect(reason)}")
        {:ok, stack, state}
    end
  end

  def evaluate_tokens([{:conditional, {if_tokens, else_tokens}, _} | tokens], stack, state) do
    [bool | stack] = stack

    if bool != 0 do
      with {:ok, {stack, state}} <- evaluate_tokens(if_tokens, stack, state) do
        evaluate_tokens(tokens, stack, state)
      end
    else
      with {:ok, {stack, state}} <- evaluate_tokens(else_tokens, stack, state) do
        evaluate_tokens(tokens, stack, state)
      end
    end
  end

  def evaluate_tokens([{:colon, _, _}, {:identifier, name, _} | tokens], stack, state) do
    # dbg(tokens)
    split_tokens =
      case Enum.split_while(tokens, fn {token, _, _} -> token != :semicolon end) do
        {_word_tokesn, []} -> {:error, {:syntax, "Missing semicolon"}}
        {word_tokens, [_semicolon_token | rest_tokens]} -> {:ok, {word_tokens, rest_tokens}}
      end

    with {:ok, {word_tokens, rest_tokens}} <- split_tokens do
      state = State.add_word(state, name, word_tokens)
      evaluate_tokens(rest_tokens, stack, state)
    end
  end

  def evaluate_tokens(tokens, stack, state) do
    # dbg(tokens)
    Enum.reduce_while(tokens, {:ok, {stack, state}}, fn token, {:ok, {stack, state}} ->
      IO.inspect(stack, charlists: :as_lists)

      case evaluate(token, stack, state) do
        {:error, reason} -> {:halt, {:error, reason}}
        {:ok, {stack, state}} -> {:cont, {:ok, {stack, state}}}
      end
    end)
  end

  def evaluate({:value, value, _}, stack, state) do
    {:ok, {[value | stack], state}}
  end

  def evaluate({:dot_quote, string, _}, stack, state) do
    IO.write(string)
    {:ok, {stack, state}}
  end

  def evaluate({:ternary_operator, op, _}, [a, b, c | rest], state) do
    case apply_op(op, a, b, c) do
      :pop -> {:ok, {rest, state}}
      result -> {:ok, {List.wrap(result) ++ rest, state}}
    end
  end

  def evaluate({:binary_operator, op, _}, [a, b | rest], state) do
    case apply_op(op, a, b) do
      :pop -> {:ok, {rest, state}}
      result -> {:ok, {List.wrap(result) ++ rest, state}}
    end
  end

  def evaluate({:unary_operator, op, _}, [a | rest], state) do
    case apply_op(op, a) do
      :pop -> {:ok, {rest, state}}
      # result -> {:ok, {[result | rest], state}}
      result -> {:ok, {List.wrap(result) ++ rest, state}}
    end
  end

  def evaluate({:identifier, name, _}, stack, state) do
    with {:ok, word_tokens} <- State.fetch_word(state, name) do
      evaluate_tokens(word_tokens, stack, state)
    else
      :error -> {:error, {:runtime, :undefined_word}}
    end
  end

  def evaluate({:ternary_operator, _, _}, _, _) do
    {:error, {:runtime, :stack_underflow}}
  end

  def evaluate({:binary_operator, _, _}, _, _) do
    {:error, {:runtime, :stack_underflow}}
  end

  def evaluate({:unary_operator, _, _}, _, _) do
    {:error, {:runtime, :stack_underflow}}
  end

  def evaluate({token_type, token_literal, location}, _, _) do
    {:error,
     {:syntax,
      "Unexpected token #{inspect(token_type)} `#{inspect(token_literal)}` at #{location}"}}
  end

  def apply_op("rot", a, b, c) do
    [c, a, b]
  end

  def apply_op("=", a, b) do
    if a == b, do: -1, else: 0
  end

  def apply_op("+", a, b) do
    a + b
  end

  def apply_op("-", a, b) do
    a - b
  end

  def apply_op("/", a, b) do
    a / b
  end

  def apply_op("*", a, b) do
    a * b
  end

  def apply_op("<", a, b) do
    if a > b, do: -1, else: 0
  end

  def apply_op(">", a, b) do
    if a < b, do: -1, else: 0
  end

  def apply_op("swap", a, b) do
    [b, a]
  end

  def apply_op("over", a, b) do
    [b, a, b]
  end

  def apply_op(".", a) do
    IO.write("#{a} ")
    :pop
  end

  def apply_op("emit", a) do
    IO.write(<<a::utf8>>)
    :pop
  end

  def apply_op("dup", a) do
    [a, a]
  end

  def apply_op("sqrt", a) do
    :math.sqrt(a)
  end

  def apply_op("drop", _a) do
    []
  end
end
