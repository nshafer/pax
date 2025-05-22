defmodule Pax.Token do
  def examine(token) do
    with(
      {:ok, protected, payload, signature} <- split_token(token),
      {:ok, protected} <- Base.url_decode64(protected, padding: false),
      {:ok, payload} <- Base.url_decode64(payload, padding: false),
      {:ok, signature} <- Base.url_decode64(signature, padding: false),
      {data, signed, max_age, expires} <- decode_token_payload(payload)
    ) do
      {:ok,
       [
         protected: protected,
         data: data,
         max_age_seconds: max_age,
         signed: signed,
         expires: expires,
         signature: signature
       ]}
    else
      :error -> {:error, :invalid_token}
      {:error, reason} -> {:error, reason}
      _ -> {:error, :unknown}
    end
  end

  def examine(context, salt, token, opts \\ []) do
    with {:ok, result} <- examine(token) do
      case Phoenix.Token.verify(context, salt, token, opts) do
        {:ok, data} ->
          {:ok,
           result
           |> Keyword.put(:verified, true)
           |> Keyword.put(:data, data)}

        {:error, reason} ->
          {:ok, Keyword.put(result, :verified, reason)}
      end
    end
  end

  defp split_token(token) do
    with [protected, payload, signature] <- String.split(token, ".", parts: 3) do
      {:ok, protected, payload, signature}
    else
      _ -> {:error, :invalid_token}
    end
  end

  defp decode_token_payload(payload) do
    case Plug.Crypto.non_executable_binary_to_term(payload) do
      {data, signed_unix, max_age} when is_integer(signed_unix) and is_integer(max_age) ->
        with(
          {:ok, signed} <- DateTime.from_unix(signed_unix, :millisecond),
          expires <- DateTime.add(signed, max_age, :second)
        ) do
          {data, signed, max_age, expires}
        end

      data ->
        {data, nil, nil, nil}
    end
  end
end
