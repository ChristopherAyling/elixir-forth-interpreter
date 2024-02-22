defmodule ForthTest do
  alias Forth.Evaluator
  alias Forth.Tokeniser
  use ExUnit.Case
  import ExUnit.CaptureIO

  def sigil_F(text, [?a]) do
    with {:ok, tokens, _meta} <- Tokeniser.tokenize(text) do
      with {:ok, {stack, state}} <- Evaluator.evaluate(tokens) do
        {:ok, {Enum.reverse(stack), state}}
      end
    end
  end

  def sigil_F(text, []) do
    with {:ok, tokens, _meta} <- Tokeniser.tokenize(text) do
      with {:ok, {stack, state}} <- Evaluator.evaluate(tokens) do
        {:ok, Enum.reverse(stack)}
      end
    end
  end

  describe "Adding Some Numbers" do
    test "1" do
      assert {:ok, [1, 2, 3]} == ~F"""
             1
             2
             3
             """
    end

    test "2" do
      assert {:ok, [1, 5]} == ~F"""
             1
             2
             3
             +
             """
    end

    test "3" do
      assert {:ok, [579]} == ~F"123 456 +"
    end

    test "4" do
      assert {:ok, [70]} = ~F"5 2 + 10 *"
    end
  end

  describe "Defining Words" do
    test "1" do
      {:ok, {stack, state}} = ~F"""
      : foo 100 + ;
      1000 foo
      foo foo foo
      """a

      assert stack == [1400]
      assert Map.has_key?(state.words, "foo")
    end
  end

  describe "Stack Manipulation" do
    test "dup" do
      {:ok, [1, 2, 3, 3]} = ~F"1 2 3 dup"
    end

    test "drop" do
      {:ok, [1, 2]} = ~F"1 2 3 drop"
    end

    test "swap" do
      {:ok, [1, 2, 4, 3]} = ~F"1 2 3 4 swap"
    end

    test "over" do
      {:ok, [1, 2, 3, 2]} = ~F"1 2 3 over"
    end

    test "rot" do
      {:ok, [2, 3, 1]} = ~F"1 2 3 rot"
    end
  end

  describe "Generating Output" do
    test "period" do
      assert capture_io(fn -> {:ok, _} = ~F"1 . 2 . 3 . 4 5 6 . . ." end) == "1 2 3 6 5 4 "
    end

    test "emit" do
      assert capture_io(fn -> {:ok, _} = ~F"33 119 111 87 emit emit emit emit" end) == "Wow!"
    end

    test "cr" do
      assert capture_io(fn -> {:ok, _} = ~F"cr 100 . cr 200 . cr 300 ." end) ==
               "\n100 \n200 \n300 "
    end

    test "dot quote" do
      assert capture_io(fn -> {:ok, _} = ~F|." Hello there!"| end) == "Hello there!"
    end

    test "dot quote big" do
      assert capture_io(fn -> {:ok, _} = ~F|
      : print-stack-top  cr dup ." The top of the stack is " . cr ." which looks like '" dup emit ." ' in ascii  " ;
        48 print-stack-top
      | end) == "\nThe top of the stack is 48 \nwhich looks like '0' in ascii  "
    end
  end

  describe "Conditionals and Loops" do
    test "if then" do
      {:ok, [42]} = ~F"-1 if 42 then"
    end

    test "fizz buzz 1" do
      assert capture_io(fn ->
               {:ok, []} = ~F"""
               : buzz?  5 mod 0 = if ." Buzz" then ;
               3 buzz?
               4 buzz?
               5 buzz?
               """
             end) == "Buzz"
    end

    test "if else then" do
      assert capture_io(fn ->
      {:ok, []} = ~F"""
      : is-it-zero?  0 = if ." Yes!" else ." No!" then ;
      0 is-it-zero?
      1 is-it-zero?
      2 is-it-zero?
      """
      end) == "Yes!No!No!"
    end

    test "boolean logic" do
      assert {:ok, [-1, -1, 0, 0, 0, -1]} == ~F"""
      3 4 < 20 30 < and
      3 4 < 20 30 > or
      3 4 < invert

      1 3 mod 0 =
      2 3 mod 0 =
      3 3 mod 0 =
      """
    end

    test "fizz buzz" do
      expected = "\n1 \n2 \nFizz\n4 \nBuzz\nFizz\n7 \n8 \nFizz\nBuzz\n11 \nFizz\n13 \n14 \nFizzBuzz\n16 \n17 \nFizz\n19 \nBuzz\nFizz\n22 \n23 \nFizz\nBuzz"

      assert capture_io(fn ->
      {:ok, _} = ~F"""
      : fizz?  3 mod 0 = dup if ." Fizz" then ;
      : buzz?  5 mod 0 = dup if ." Buzz" then ;
      : fizz-buzz?  dup fizz? swap buzz? or invert ;
      : my-fizz-buzz  25 1 do cr i fizz-buzz? if i . then loop ;
      my-fizz-buzz
      """
      end) == expected
    end
  end

  describe "variables and constants" do
    test "declare a variable" do
      ~F"""
      variable balance
      balance
      """
    end

    test "store a variable" do
      ~F"""
      variable balance
      123 balance !
      """
    end

    test "fetch a variable" do
      {:ok, [123]} = ~F"""
      variable balance
      123 balance !
      balance @
      """
    end
  end
end
