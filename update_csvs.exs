defmodule AdventureWorks do
  def prepare do
    Path.expand(".")
    |> Kernel.<>("/*.csv")
    |> Path.wildcard()
    |> Task.async_stream(
      fn filename ->
        filename
        |> File.stream!()
        |> Enum.take(1)
        |> hd()
        |> :unicode.bom_to_encoding()
        |> case do
          {{:utf16, :little}, 2} -> process(filename)
          _ -> :skip
        end
      end,
      max_concurrency: System.schedulers()
    )
    |> Enum.to_list()
  end

  def process(filename) do
    IO.puts("processing #{filename}")

    processed_content =
      filename
      |> File.read!()
      |> String.slice(2..-1)
      |> :unicode.characters_to_binary({:utf16, :little})
      |> String.replace("\"", "\"\"")
      |> String.replace("\r\n", "\n")
      |> String.split(["&|\n"])
      |> case do
        [tab_separated_string] -> tab_separated_string
        list_of_rows -> process_rows(list_of_rows)
      end

    File.write(filename, processed_content)
  end

  def process_rows(list_of_rows) do
    list_of_rows
    |> Enum.map(fn line ->
      line
      |> String.split("+|")
      |> Enum.map(&process_string/1)
      |> Enum.intersperse("\t")
    end)
    |> Enum.intersperse("\n")
  end

  def process_string(string) do
    case :unicode.bom_to_encoding(string) do
      {:latin1, 0} ->
        if String.contains?(string, ["\t", "\"\""]) do
          ["\"", string, "\""]
        else
          String.trim(string)
        end

      {:utf8, 3} ->
        string
        |> String.slice(1..-1)
        |> then(&["\"", &1, "\""])
    end
  end
end

AdventureWorks.prepare()

# Create the database and tables, import the data, and set up the views and keys with:

# psql -c "CREATE DATABASE \"Adventureworks\";"
# psql -d Adventureworks < install.sql
