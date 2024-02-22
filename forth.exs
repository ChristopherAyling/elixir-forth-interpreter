case System.argv() do
 [] -> Forth.run()
 [path] -> Forth.run_file(path)
end
