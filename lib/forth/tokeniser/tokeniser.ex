defmodule Forth.Tokeniser do
  alias Forth.Tokeniser.Meta, as: Meta

  def tokenize(text, filename \\ "interactive") do
    text |> String.split("", trim: true) |> tokenize([], Meta.new(filename))
  end

  def tokenize([], tokens, _progress) do
    {:ok, Enum.reverse(tokens)}
  end

  def tokenize([c | rest] = cs, tokens, meta) do
    cond do
      c == "" -> tokenize(rest, tokens, meta)
      is_newline(c) -> tokenize(rest, tokens, meta |> Meta.incr_line())
      is_whitespace(c) -> tokenize(rest, tokens, meta |> Meta.incr_column())
      c == ":" -> tokenize(rest, [{:colon, ":", meta} | tokens], meta |> Meta.incr_column())
      c == ";" -> tokenize(rest, [{:semicolon, ";", meta} | tokens], meta |> Meta.incr_column())
      c == "(" -> read_comment(cs, tokens, meta)
      is_dot_quote(cs) -> read_dot_quote(cs, tokens, meta)
      is_conditional(cs) -> read_conditional(cs, tokens, meta)
      is_ternary_operator(cs) -> read_ternary_operator(cs, tokens, meta)
      is_binary_operator(cs) -> read_binary_operator(cs, tokens, meta)
      is_unary_operator(cs) -> read_unary_operator(cs, tokens, meta)
      is_letter(c) -> read_identifier(cs, tokens, meta)
      is_value(c) -> read_value(cs, tokens, meta)
      true -> {:error, "Unexpected character `#{c}` at position #{meta.line}:#{meta.column}"}
    end
  end

  def is_conditional(cs) do
    case cs do
      ["i", "f", " " | _] -> true
      _ -> false
    end
  end

  def read_conditional(["i", "f", " " | cs], tokens, meta) do
    cs_string = Enum.join(cs)
    [if_body, rest] = String.split(cs_string, "then")

    {if_branch, else_branch} =
      case String.split(if_body, "else") do
        [if_branch] -> {if_branch, ""}
        [if_branch, else_branch] -> {if_branch, else_branch}
      end

    {:ok, if_tokens} = tokenize(if_branch)
    {:ok, else_tokens} = tokenize(else_branch)
    # dbg({if_tokens, else_tokens})

    token = {:conditional, {if_tokens, else_tokens}, meta}

    tokenize(
      rest |> String.split(""),
      [token | tokens],
      meta |> Meta.incr_column(String.length(cs_string) + 3)
    )
  end

  def is_dot_quote(cs) do
    case cs do
      [".", "\"", " " | _] -> true
      _ -> false
    end
  end

  def read_dot_quote([".", "\"", " " | cs], tokens, meta) do
    {string, ["\"" | rest]} = Enum.split_while(cs, &(&1 != "\""))
    string = Enum.join(string)

    tokenize(
      rest,
      [{:dot_quote, string, meta} | tokens],
      meta |> Meta.incr_column(String.length(string) + 3)
    )
  end

  def is_letter(c) do
    c =~ ~r/[a-zA-Z-_?]/
  end

  def is_newline(c) do
    c == "\n"
  end

  def is_whitespace(c) do
    c =~ ~r/\s/
  end

  def is_value(c) do
    is_quote(c) or is_digit(c)
  end

  def read_value([c | _rest] = cs, tokens, meta) do
    cond do
      # is_quote(c) -> read_string(rest, tokens, meta |> Meta.incr_column())
      is_digit(c) -> read_number(cs, tokens, meta)
    end
  end

  def read_comment(cs, tokens, meta) do
    {comment, [_closing_paren | rest]} = Enum.split_while(cs, &(&1 != ")"))
    # one for the opening paren, one for the closing paren
    comment_size = length(comment) + 2
    tokenize(rest, tokens, meta |> Meta.incr_column(comment_size))
  end

  def is_quote(c) do
    c == "\""
  end

  def read_string(cs, tokens, meta) do
    {string, rest} = Enum.split_while(cs, &(&1 != "\""))
    string = Enum.join(string)

    tokenize(
      rest,
      [{:value, string, meta} | tokens],
      meta |> Meta.incr_column(String.length(string) + 2)
    )
  end

  def is_digit(c) do
    c =~ ~r/[0-9]/
  end

  def read_number(cs, tokens, meta) do
    {number_chars, rest} = Enum.split_while(cs, &is_digit/1)
    number_string = Enum.join(number_chars)
    number = String.to_integer(number_string)

    tokenize(
      rest,
      [{:value, number, meta} | tokens],
      meta |> Meta.incr_column(String.length(number_string))
    )
  end

  def is_ternary_operator(cs) do
    case cs do
      ["r", "o", "t" | _] -> true
      _ -> false
    end
  end

  def read_ternary_operator(cs, tokens, meta) do
    {op, rest} =
      case cs do
        ["r", "o", "t" | rest] -> {"rot", rest}
        _ -> false
      end

    tokenize(
      rest,
      [{:ternary_operator, op, meta} | tokens],
      meta |> Meta.incr_column(String.length(op))
    )
  end

  def is_binary_operator(cs) do
    case cs do
      ["=" | _] -> true
      ["+" | _] -> true
      ["-" | _] -> true
      ["/" | _] -> true
      ["*" | _] -> true
      ["<" | _] -> true
      [">" | _] -> true
      ["s", "w", "a", "p" | _] -> true
      ["o", "v", "e", "r" | _] -> true
      _ -> false
    end
  end

  def read_binary_operator(cs, tokens, meta) do
    {op, rest} =
      case cs do
        ["=" | rest] -> {"=", rest}
        ["+" | rest] -> {"+", rest}
        ["-" | rest] -> {"-", rest}
        ["/" | rest] -> {"/", rest}
        ["*" | rest] -> {"*", rest}
        ["<" | rest] -> {"<", rest}
        [">" | rest] -> {">", rest}
        ["s", "w", "a", "p" | rest] -> {"swap", rest}
        ["o", "v", "e", "r" | rest] -> {"over", rest}
      end

    tokenize(
      rest,
      [{:binary_operator, op, meta} | tokens],
      meta |> Meta.incr_column(String.length(op))
    )
  end

  def is_unary_operator(cs) do
    case cs do
      ["." | _] -> true
      ["e", "m", "i", "t" | _] -> true
      ["d", "u", "p" | _] -> true
      ["d", "r", "o", "p" | _] -> true
      ["s", "q", "r", "t" | _] -> true
      _ -> false
    end
  end

  def read_unary_operator(cs, tokens, meta) do
    {op, rest} =
      case cs do
        ["." | rest] -> {".", rest}
        ["e", "m", "i", "t" | rest] -> {"emit", rest}
        ["d", "u", "p" | rest] -> {"dup", rest}
        ["d", "r", "o", "p" | rest] -> {"drop", rest}
        ["s", "q", "r", "t" | rest] -> {"sqrt", rest}
      end

    tokenize(
      rest,
      [{:unary_operator, op, meta} | tokens],
      meta |> Meta.incr_column(String.length(op))
    )
  end

  def read_identifier(cs, tokens, meta) do
    {identifier, rest} = Enum.split_while(cs, &is_letter/1)
    identifier = Enum.join(identifier)

    tokenize(
      rest,
      [{:identifier, identifier, meta} | tokens],
      meta |> Meta.incr_column(String.length(identifier))
    )
  end
end
