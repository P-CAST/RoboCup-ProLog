:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_json)).

:- consult('game.pl').

:- http_handler(root(action), handle_action, []).

start_server :-
    http_server(http_dispatch, [port(5000)]).

handle_action(Request) :-
    http_read_json_dict(Request, Dict),
    Action = Dict.get(action),
    ( process_action(Action, Dict, Response)
    ; process_action(Action, Response)
    ),
    !,
    reply_json_dict(Response),
    clear_events.

% ============== STEP ==============
process_action("step", Response) :-
    current_state(State),
    ( terminal(State) ->
        true
    ;
        current_team(State, Team),
        choose_action(State, Team, Action),
        apply_action(State, Team, Action, NewState),
        store_state(NewState),
        emit_events(State, NewState)
    ),
    build_game_state(Response).

% ============== RESET ==============
process_action("reset", Response) :-
    init_live_state,
    build_game_state(Response).

% ============== SET MODE ==============
process_action("set_mode", Dict, _{status: "ok"}) :-
    Mode = Dict.get(mode),
    retractall(game_mode(_)),
    ( (Mode == "ai_vs_ai" ; Mode == ai_vs_ai) ->
        assertz(game_mode(ai_vs_ai))
    ; (Mode == "slider_vs_ai" ; Mode == slider_vs_ai) ->
        assertz(game_mode(slider_vs_ai))
    ;
        assertz(game_mode(ai_vs_ai))
    ).

% ============== SET STRATEGY ==============
process_action("set_strategy", Dict, _{status: "ok"}) :-
    TeamStr = Dict.get(team),
    Agg     = Dict.get(aggression),
    ( (TeamStr == "teamA" ; TeamStr == teamA) -> T = teamA
    ; (TeamStr == "teamB" ; TeamStr == teamB) -> T = teamB
    ; T = teamA
    ),
    retractall(strategy_aggression(T, _)),
    assertz(strategy_aggression(T, Agg)).

:- initialization(init_live_state).
