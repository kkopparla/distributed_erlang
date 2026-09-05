-module(miner_util).
-export([
    sha256/1,
    has_leading_zeros/2,
    to_hex/1,
    generate_input/2,
    verify_test_vector/0
]).

%% @doc Compute raw SHA-256 binary hash of the input binary.
-spec sha256(binary()) -> binary().
sha256(Data) when is_binary(Data) ->
    crypto:hash(sha256, Data).

%% @doc Check if the SHA-256 hash has at least K leading zeros in hexadecimal format.
%% In hex, each byte represents two hexadecimal digits.
%% If K >= 2, the leading byte must be 0x00.
%% If K == 1, the leading byte must be < 0x10 (i.e. high nibble is 0).
-spec has_leading_zeros(binary(), non_neg_integer()) -> boolean().
has_leading_zeros(_, 0) ->
    true;
has_leading_zeros(<<>>, K) when K > 0 ->
    false;
has_leading_zeros(<<0, Rest/binary>>, K) when K >= 2 ->
    has_leading_zeros(Rest, K - 2);
has_leading_zeros(<<B, _/binary>>, 1) when B < 16 ->
    true;
has_leading_zeros(_, _) ->
    false.

%% @doc Convert a binary into a lowercase hexadecimal string.
-spec to_hex(binary()) -> string().
to_hex(Binary) when is_binary(Binary) ->
    lists:flatten([io_lib:format("~2.16.0b", [B]) || <<B>> <= Binary]).

%% @doc Generate input binary: Prefix ++ Index
-spec generate_input(binary(), integer()) -> binary().
generate_input(Prefix, Index) ->
    IndexBin = integer_to_binary(Index),
    <<Prefix/binary, IndexBin/binary>>.

%% @doc Verify the official COP5615 test vector:
%% Text "COP5615 is a boring class" must hash to
%% "fb4431b6a2df71b6cbad961e08fa06ee6fff47e3bc14e977f4b2ea57caee48a4"
-spec verify_test_vector() -> boolean().
verify_test_vector() ->
    Input = <<"COP5615 is a boring class">>,
    Hash = sha256(Input),
    Hex = to_hex(Hash),
    Expected = "fb4431b6a2df71b6cbad961e08fa06ee6fff47e3bc14e977f4b2ea57caee48a4",
    Hex =:= Expected.
