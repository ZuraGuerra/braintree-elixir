defmodule Braintree.XML.Entity do
  @external_resource entities = Path.join([__DIR__, "../../priv/entities.txt"])

  @doc """
  Replace any escaped HTML entities with the unicode value.

  ## Examples

      iex> Braintree.XML.Entity.decode("&lt;tag&gt;")
      "<tag>"

      iex> Braintree.XML.Entity.decode("S&#248;ren")
      "Søren"

      iex> Braintree.XML.Entity.decode("Normal")
      "Normal"
  """
  def decode(string) do
    Regex.replace(~r/\&([^\s]+);/U, string, &replace/2)
  end

  @doc """
  Encode all illegal XML characters by replacing them with corresponding
  entities.

  ## Examples

      iex> Braintree.XML.Entity.encode("<tag>")
      "&lt;tag&gt;"

      iex> Braintree.XML.Entity.encode("Here & There")
      "Here &amp; There"
  """
  def encode(string) do
    string
    |> String.graphemes
    |> Enum.map(&escape/1)
    |> Enum.join
  end

  for line <- File.stream!(entities) do
    [name, character, codepoint] = String.split(line, ",")

    defp replace(_, unquote(name)), do: unquote(character)
    defp replace(_, unquote(codepoint)), do: unquote(character)
  end

  defp replace(_, "#x" <> code), do: <<String.to_integer(code, 16)::utf8>>
  defp replace(_, "#" <> code),  do: <<String.to_integer(code)::utf8>>
  defp replace(original, _),     do: original

  defp escape("'"),      do: "&apos;"
  defp escape("\""),     do: "&quot;"
  defp escape("&"),      do: "&amp;"
  defp escape("<"),      do: "&lt;"
  defp escape(">"),      do: "&gt;"
  defp escape(original), do: original
end
