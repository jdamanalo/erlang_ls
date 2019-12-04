-module(els_document_highlight_provider).

-behaviour(els_provider).

-export([ handle_request/2
        , is_enabled/0
        ]).

%%==============================================================================
%% Includes
%%==============================================================================
-include("erlang_ls.hrl").

%%==============================================================================
%% els_provider functions
%%==============================================================================

-spec is_enabled() -> boolean().
is_enabled() ->
  true.

-spec handle_request(any(), els_provider:state()) ->
  {any(), els_provider:state()}.
handle_request({document_highlight, Params}, State) ->
  #{ <<"position">>     := #{ <<"line">>      := Line
                            , <<"character">> := Character
                            }
   , <<"textDocument">> := #{<<"uri">> := Uri}
   } = Params,
  {ok, Document} = els_utils:find_document(Uri),
  case
    els_document:get_element_at_pos(Document, Line + 1, Character + 1)
  of
    [POI | _] -> {find_highlights(Uri, POI), State};
    []        -> {null, State}
  end.

%%==============================================================================
%% Internal functions
%%==============================================================================

-spec find_highlights(binary(), poi()) -> any().
find_highlights(Uri, #{ kind := Kind
                      , id   := Id
                      }) when Kind =:= application;
                              Kind =:= implicit_fun;
                              Kind =:= function;
                              Kind =:= variable;
                              Kind =:= export_entry ->
  Key = case Id of
          {F, A}    -> {els_uri:module(Uri), F, A};
          {M, F, A} -> {M, F, A};
          V         -> {els_uri:module(Uri), V, 0}
        end,
  case els_db:find_multi(references, Key) of
    {error, not_found} ->
      null;
    {ok, Refs} ->
      R = [document_highlight(R) ||
          {_, #{uri := U, range := R}} <- ordsets:to_list(Refs)
          , Uri == U ],
      R
  end;
find_highlights(_Uri, _POI) ->
  null.

-spec document_highlight(poi_range()) -> map().
document_highlight(Range) ->
    %% TODO:AZ:range as displayed ends one col too early
  #{ range => els_protocol:range(Range)
   , kind => ?DOCUMENT_HIGHLIGHT_KIND_TEXT
   }.