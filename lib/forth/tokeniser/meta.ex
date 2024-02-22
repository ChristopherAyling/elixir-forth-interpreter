defmodule Forth.Tokeniser.Meta do
  defstruct [:line, :column, :filename]

  def new(filename \\ "interactive") do
    %__MODULE__{line: 0, column: 0, filename: filename}
  end

  def incr_line(meta) do
    %__MODULE__{meta | line: meta.line + 1, column: 0}
  end

  def incr_column(meta) do
    %__MODULE__{meta | column: meta.column + 1}
  end

  def incr_column(meta, n) do
    %__MODULE__{meta | column: meta.column + n}
  end
end

defimpl String.Chars, for: Forth.Tokeniser.Meta do
  def to_string(meta) do
    "#{meta.filename}:#{meta.line}:#{meta.column}"
  end
end
