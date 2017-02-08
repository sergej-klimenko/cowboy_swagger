%%% @doc Cowboy Swagger Handler. This handler exposes a GET operation
%%%      to enable that  `swagger.json' can be retrieved from embedded
%%%      Swagger-UI (located in `priv/swagger' folder).
-module(cowboy_swagger_handler).

%% Trails
-behaviour(trails_handler).
-export([trails/0, trails/1]).

%% Cowboy handler
-export([init/3, handle/2, terminate/3]).

-type route_match() :: '_' | iodata().
-type options() :: #{server => ranch:ref(), host => route_match()}.

-define(APP_ENV(X, Y), application:get_env(cowboy_swagger, X, Y)).
-define(JSON_URL, "http://petstore.swagger.io/v2/swagger.json").
-define(CLIENT_ID, "your-client-id").
-define(CLIENT_SECRET, "your-client-secret-if-required").
-define(UI_THEME, "newspaper").

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Trails
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% @hidden
%% @doc Implements `trails_handler:trails/0' callback. This function returns
%%      trails routes for both: static content (Swagger-UI) and this handler
%%      that returns the `swagger.json'.
-spec trails() -> trails:trails().
trails() -> trails(#{}).
-spec trails(Options::options()) -> trails:trails().
trails(Options) ->
  StaticFiles =
    case application:get_env(cowboy_swagger, static_files) of
      {ok, Val} -> Val;
      _         -> filename:join(cowboy_swagger_priv(), "swagger")
    end,
  Redirect = trails:trail(
    "/api-docs",
    ?MODULE,
    [],
    #{get => #{hidden => true}}),
  Static = trails:trail(
    "/api-docs/[...]",
    cowboy_static,
    {dir, StaticFiles, [{mimetypes, cow_mimetypes, all}]},
    #{get => #{hidden => true}}),
  MD = #{get => #{hidden => true}},
  Handler = trails:trail(
    "/api-docs/swagger.json", cowboy_swagger_json_handler, Options, MD),
  [Redirect, Handler, Static].

%% @private
-spec cowboy_swagger_priv() -> string().
cowboy_swagger_priv() ->
  case code:priv_dir(cowboy_swagger) of
    {error, bad_name} ->
      case code:which(cowboy_swagger_handler) of
        cover_compiled -> "../../priv"; % required for tests to work
        BeamPath -> filename:join([filename:dirname(BeamPath) , ".." , "priv"])
      end;
    Path -> Path
  end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Cowboy handler
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

init(_, Req, _Opts) ->
    {ok, Req, #{}}.

handle(Req, State) ->
    {Method, _} = cowboy_req:method(Req),
    {ok, Reply} = handle_req(Method, Req),
    {ok, Reply, State}.

handle_req(<<"GET">>, Req) ->
    Data = [
            {json_url, ?APP_ENV(json_url, ?JSON_URL)},
            {client_id, ?APP_ENV(client_id, ?CLIENT_ID)},
            {client_secret, ?APP_ENV(client_secret, ?CLIENT_SECRET)},
            {ui_theme, ?APP_ENV(ui_theme, ?UI_THEME)}
           ],
    {ok, Body2} = index_dtl:render(Data),
    cowboy_req:reply(200, [{<<"content-type">>, <<"text/html">>}], Body2, Req).

terminate(_Reason, _Req, _State) ->
    ok.
