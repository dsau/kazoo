%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2018, 2600Hz
%%% @doc Handlers for various AMQP payloads
%%% @end
%%%-----------------------------------------------------------------------------
-module(j5_channel_destroy).

-export([handle_req/2]).

-include("jonny5.hrl").

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec handle_req(kz_json:object(), kz_term:proplist()) -> 'ok'.
handle_req(JObj, _Props) ->
    'true' = kapi_call:event_v(JObj),
    kz_util:put_callid(JObj),
    timer:sleep(1000 + rand:uniform(2000)),
    Request = j5_request:from_jobj(JObj),
    _ = account_reconcile_cdr(Request),
    _ = reseller_reconcile_cdr(Request),
    'ok'.

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec account_reconcile_cdr(j5_request:request()) -> 'ok'.
account_reconcile_cdr(Request) ->
    case j5_request:account_id(Request) of
        'undefined' -> 'ok';
        AccountId ->
            reconcile_cdr(Request, j5_limits:get(AccountId))
    end.

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec reseller_reconcile_cdr(j5_request:request()) -> 'ok'.
reseller_reconcile_cdr(Request) ->
    AccountId = j5_request:account_id(Request),
    case j5_request:reseller_id(Request) of
        'undefined' -> 'ok';
        AccountId -> 'ok';
        ResellerId ->
            reconcile_cdr(Request, j5_limits:get(ResellerId))
    end.

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec reconcile_cdr(j5_request:request(), j5_limits:limits()) -> 'ok'.
reconcile_cdr(Request, Limits) ->
    _ = j5_allotments:reconcile_cdr(Request, Limits),
    _ = j5_flat_rate:reconcile_cdr(Request, Limits),
    _ = j5_per_minute:reconcile_cdr(Request, Limits),
    'ok'.
