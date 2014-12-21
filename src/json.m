%-----------------------------------------------------------------------------%
% vim: ft=mercury ts=4 sw=4 et
%-----------------------------------------------------------------------------%
% Copyright (C) 2013-2014, Julien Fischer.
% All rights reserved.
%
% Author: Julien Fischer <jfischer@opturion.com>
%
% A Mercury library for reading and writing JSON.
%
%-----------------------------------------------------------------------------%

:- module json.
:- interface.

%-----------------------------------------------------------------------------%

:- import_module bool.
:- import_module char.
:- import_module io.
:- import_module list.
:- import_module map.
:- import_module maybe.
:- import_module stream.

%-----------------------------------------------------------------------------%
%
% JSON errors.
%

:- type json.context
    --->    context(
                stream_name   :: string,
                line_number   :: int,
                column_number :: int
            ).

    % This type describes errors that can occur while reading JSON data.
    %
:- type json.error(Error)
    --->    stream_error(Error)
            % An error has occurred in the underlying character stream.

    ;       json_error(
                error_context :: json.context,
                error_desc    :: json.error_desc
            ).

:- type json.error_desc
    --->    unexpected_eof(maybe(string))
            % unexpected end-of-file: Msg

    ;       syntax_error(string, maybe(string))
            % syntax_error(Where, MaybeMsg)
            % syntax error at 'Where': MaybeMsg

    ;       invalid_character_escape(char)

    ;       unexpected_value(string, maybe(string))

    ;       duplicate_object_member(string)

    ;       unterminated_multiline_comment

    ;       invalid_unicode_character(string)

    ;       unpaired_utf16_surrogate

    ;       other(string).

:- instance stream.error(json.error(Error)) <= stream.error(Error).

%----------------------------------------------------------------------------%
%
% Wrappers for the standard stream result types.
%

:- type json.res(T, Error) == stream.res(T, json.error(Error)).

:- type json.res(Error) == stream.res(json.error(Error)).

:- type json.result(T, Error) == stream.result(T, json.error(Error)).

:- type json.maybe_partial_res(T, Error) ==
    stream.maybe_partial_res(T, json.error(Error)).

%-----------------------------------------------------------------------------%
%
% Mercury representation of JSON values.
%

:- type json.value
    --->    null
    ;       bool(bool)
    ;       string(string)
    ;       number(float)
    ;       object(json.object)
    ;       array(json.array).

:- type json.object == map(string, json.value).

:- type json.array == list(json.value).

    % int(I) = number(float(I)).
    %
:- func json.int(int) = json.value.

%-----------------------------------------------------------------------------%
%
% Procedures for working with JSON values.
%

    % The following are true iff the given value is a JSON value of the
    % type specified by the predicate name.
    %
:- pred is_null(value::in) is semidet.
:- pred is_bool(value::in) is semidet.
:- pred is_string(value::in) is semidet.
:- pred is_number(value::in) is semidet.
:- pred is_object(value::in) is semidet.
:- pred is_array(value::in) is semidet.

    % The following are true iff the given value is a JSON value of the type
    % specified by the predicate name.  They return the underlying value.
    % The are false if the given value is not a JSON value of the type
    % specified by the predicate name.
    %
:- pred get_bool(value::in, bool::out) is semidet.
:- pred get_string(value::in, string::out) is semidet.
:- pred get_number(value::in, float::out) is semidet.
:- pred get_object(value::in, object::out) is semidet.
:- pred get_array(value::in, array::out) is semidet.

    % Return the value of a JSON number as an integer.
    % The fractional part is truncated.
    %
:- pred get_int(value::in, int::out) is semidet.

    % As above, but calls error/1 if the given value is not a JSON value of the
    % type specified by the predicate name.
    %
:- func det_get_bool(value) = bool.
:- func det_get_string(value) = string.
:- func det_get_number(value) = float.
:- func det_get_object(value) = object.
:- func det_get_array(value) = array.

:- func det_get_int(value) = int.

%-----------------------------------------------------------------------------%
%
% Procedures for working with JSON objects.
%

    % lookup_<type>(Object, Member) = Value:
    % Lookup Member in Object and return the underlying value if it is a
    % JSON value of the type specified by the predicate name.
    % Calls error/1 if Member is not a member of Object or if the member value
    % is not a JSON value of the type specified by the predicate name.
    %
:- func lookup_bool(object, string) = bool.
:- func lookup_string(object, string) = string.
:- func lookup_number(object, string) = float.
:- func lookup_object(object, string) = object.
:- func lookup_array(object, string) = array.

:- func lookup_int(object, string) = int.

%-----------------------------------------------------------------------------%
%
% JSON reader.
%

    % A JSON reader gets JSON values from an underlying character stream.
    %
:- type json.reader(Stream).

:- type json.reader_params
    --->    reader_params(
                allow_comments         :: allow_comments,
                allow_trailing_commas  :: allow_trailing_commas,
                allow_repeated_members :: allow_repeated_members
            ).

    % Should the extension that allows comments in the JSON being read be
    % enabled?
    %
:- type json.allow_comments
    --->    allow_comments
    ;       do_not_allow_comments.

    % Should the extension that allows trailing commas in JSON objects and
    % arrays be enabled?
    %
:- type json.allow_trailing_commas
    --->    allow_trailing_commas
    ;       do_not_allow_trailing_commas.

    % Should we allow repeated object members in JSON objects?
    % (And if so, how should that situation be handled?)
    %
:- type json.allow_repeated_members
     --->   do_not_allow_repeated_members
            % Return an error if a repeated object member is encountered.

    ;       allow_repeated_members_keep_first
            % If any object members are repeated, keep the first one that we
            % encounter and discard any others.

    ;       allow_repeated_members_keep_last.
            % If any object members are repeated, keep the last one that we
            % encounter and discard any others.

    % init_reader(Stream) = Reader:
    % Reader is a new JSON reader using Stream as a character stream.
    % Use the default reader parameters, with which the reader will
    % conform to the RFC 7159 definition of JSON.
    %
:- func json.init_reader(Stream) = json.reader(Stream)
    <= (
        stream.line_oriented(Stream, State),
        stream.putback(Stream, char, State, Error)
    ).

    % init_reader(Stream, Parameters) = Reader:
    % As above, but allow reader parameters to be set by the caller.
    %
:- func json.init_reader(Stream, reader_params) = json.reader(Stream)
    <= (
        stream.line_oriented(Stream, State),
        stream.putback(Stream, char, State, Error)
    ).

    % get_value(Reader, Result, !State):
    % Get a JSON value from Reader.
    %
:- pred json.get_value(json.reader(Stream)::in,
    json.result(json.value, Error)::out, State::di, State::uo) is det
    <= (
        stream.line_oriented(Stream, State),
        stream.putback(Stream, char, State, Error)
    ).

    % get_object(Reader, Result, !State):
    % Get a JSON object from Reader.
    %
:- pred json.get_object(json.reader(Stream)::in,
    json.result(json.object, Error)::out, State::di, State::uo) is det
    <= (
        stream.line_oriented(Stream, State),
        stream.putback(Stream, char, State, Error)
    ).

    % get_array(Reader, Result, !State):
    % Get a JSON array from Reader.
    %
:- pred json.get_array(json.reader(Stream)::in,
    json.result(json.array, Error)::out, State::di, State::uo) is det
    <= (
        stream.line_oriented(Stream, State),
        stream.putback(Stream, char, State, Error)
    ).

%-----------------------------------------------------------------------------%
%
% Folding over object members.
%

    % object_fold(Reader, Pred, InitialAcc, Result, !State):
    %
:- pred json.object_fold(json.reader(Stream), pred(string, json.value, A, A),
    A, json.maybe_partial_res(A, Error), State, State)
    <= (
        stream.line_oriented(Stream, State),
        stream.putback(Stream, char, State, Error)
    ).
:- mode json.object_fold(in, in(pred(in, in, in, out) is det),
    in, out, di, uo) is det.
:- mode json.object_fold(in, in(pred(in, in, in, out) is cc_multi),
    in, out, di, uo) is cc_multi.

    % object_fold_state(Reader, Pred, InitialAcc, Result, !State):
    %
:- pred json.object_fold_state(json.reader(Stream),
    pred(string, json.value, A, A, State, State),
    A, json.maybe_partial_res(A, Error), State, State)
    <= (
        stream.line_oriented(Stream, State),
        stream.putback(Stream, char, State, Error)
    ).
:- mode json.object_fold_state(in,
    in(pred(in, in, in, out, di, uo) is det),
    in, out, di, uo) is det.
:- mode json.object_fold_state(in,
    in(pred(in, in, in, out, di, uo) is cc_multi),
    in, out, di, uo) is cc_multi.

%-----------------------------------------------------------------------------%
%
% Folding over array elements.
%

    % array_fold(Reader, Pred, InitialAcc, Result, !State):
    %
:- pred json.array_fold(json.reader(Stream), pred(json.value, A, A),
    A, json.maybe_partial_res(A, Error), State, State)
    <= (
        stream.line_oriented(Stream, State),
        stream.putback(Stream, char, State, Error)
    ).
:- mode json.array_fold(in, in(pred(in, in, out) is det),
    in, out, di, uo) is det.
:- mode json.array_fold(in, in(pred(in, in, out) is cc_multi),
    in, out, di, uo) is cc_multi.

    % array_fold(Reader, Pred, InitialAcc, Result, !State):
    %
:- pred json.array_fold_state(json.reader(Stream),
    pred(json.value, A, A, State, State),
    A, json.maybe_partial_res(A, Error), State, State)
    <= (
        stream.line_oriented(Stream, State),
        stream.putback(Stream, char, State, Error)
    ).
:- mode json.array_fold_state(in,
    in(pred(in, in, out, di, uo) is det),
    in, out, di, uo) is det.
:- mode json.array_fold_state(in,
    in(pred(in, in, out, di, uo) is cc_multi),
    in, out, di, uo) is cc_multi.

%-----------------------------------------------------------------------------%
%
% Stream type class instances for JSON readers.
%

% XXX these should be polymorphic in the stream state type, but unfortunately
% restrictions in the type class system mean this is not currently possible.

:- instance stream.stream(json.reader(Stream), io)
    <= stream.stream(Stream, io).

:- instance stream.input(json.reader(Stream), io) <= stream.input(Stream, io).

:- instance stream.reader(json.reader(Stream), json.value, io,
    json.error(Error))
    <= (
        stream.line_oriented(Stream, io),
        stream.putback(Stream, char, io, Error)
    ).

%-----------------------------------------------------------------------------%
%
% JSON writer.
%

    % A JSON reader puts JSON values to an underlying string writer stream.
    %
:- type json.writer(Stream).

:- type json.writer_params
    --->    writer_params(
                output_style :: output_style
            ).

:- type json.output_style
    --->    compact
    ;       pretty.

    % init_writer(Stream) = Writer:
    % Writer is a new JSON writer that writes JSON values to Stream.
    %
:- func json.init_writer(Stream) = json.writer(Stream)
    <= (
        stream.writer(Stream, char, State),
        stream.writer(Stream, string, State)
    ).

    % init_writer(Stream, Parameters) = Writer:
    %
:- func json.init_writer(Stream, writer_params) = json.writer(Stream).

    % put_json(Writer, Value, !State):
    % Write the JSON value Value using the given Writer.
    %
:- pred json.put_json(json.writer(Stream)::in, json.value::in,
    State::di, State::uo) is det
    <= (
        stream.writer(Stream, char, State),
        stream.writer(Stream, string, State)
    ).

:- type json.comment
    --->    comment_eol(string)
    ;       comment_multiline(string).

    % put_comment(Writer, Comment, !State):
    %
:- pred json.put_comment(json.writer(Stream)::in, json.comment::in,
    State::di, State::uo) is det
    <= (
        stream.writer(Stream, char, State),
        stream.writer(Stream, string, State)
    ).

%-----------------------------------------------------------------------------%
%
% Marshaling between Mercury types and JSON objects.
%

% NOTE: THIS IS STILL WORK-IN-PROGRESS.

% The mapping between Mercury types and JSON is:
%
%                     Mercury             JSON
% Primitive types:
%                     int                  number#
%                     string               string
%                     float##              number
%                     char                 string
%
% # cannot have a fractional part.
% ## only finite floats may be converted to JSON.
%
% Library types:
%
%                     bool/0               Boolean
%                     maybe/1              null for "no" or
%                                          arg of yes/1
%
%                     date/0               string
%                     duration/0           string
%                     integer/0            string
%
%                     list/1               array##
%
% ## in principle, most sequence types in the standard library
% could be converted to/from JSON arrays.
%
% User-defined typs:
%
%                     enumerations          string
%                     discriminated unions  objects
%
% User-defined non-enumeration d.u. types must have all their
% fields named in order to be marshaled to JSON.
%
% Cannot be marshaled to JSON:
%   - foreign types
%   - univs
%   - d.u types with existentially quantified data constructors
%   - d.u types without field names
%   - no higher-order types
%
% TODO
%   - provide support for a greater range of stdlib types.

    % from_type(Type) = MaybeValue:
    % MaybeValue = 'ok(Value)' if Type is a Mercury term corresponding
    % to the JSON value Value and 'error(...)' otherwise.
    %
:- func json.from_type(T) = maybe_error(json.value).

    % to_type(Value) = MaybeType:
    % MaybeType is 'ok(Type)' if Value is a JSON object corresponding
    % to the Mercury value Type and 'error(...)' otherwise.
    %
:- func json.to_type(json.value) = maybe_error(T).

%-----------------------------------------------------------------------------%
%-----------------------------------------------------------------------------%

:- implementation.

:- include_module json.char_buffer.
:- include_module json.json_lexer.
:- include_module json.json_parser.
:- include_module json.marshal.
:- include_module json.unmarshal.
:- include_module json.writer.

:- import_module json.char_buffer.
:- import_module json.json_lexer.
:- import_module json.json_parser.
:- import_module json.marshal.
:- import_module json.unmarshal.
:- import_module json.writer.

:- import_module construct.
:- import_module deconstruct.
:- import_module int.
:- import_module float.
:- import_module mutvar.
:- import_module string.
:- import_module require.
:- import_module type_desc.
:- import_module univ.

%-----------------------------------------------------------------------------%
%
% JSON reader.
%

:- type json.reader(Stream)
    --->    json_reader(
                json_reader_stream    :: Stream,
                json_comments         :: allow_comments,
                json_trailing_commas  :: allow_trailing_commas,
                json_repeated_members :: allow_repeated_members,
                json_column_number    :: mutvar(int)
            ).

json.init_reader(Stream) = Reader :-
    promise_pure (
        impure new_mutvar(0, ColNumVar),
        Reader = json_reader(
            Stream,
            do_not_allow_comments,
            do_not_allow_trailing_commas,
            do_not_allow_repeated_members,
            ColNumVar
        )
    ).

json.init_reader(Stream, Params) = Reader :-
    Params = reader_params(
        AllowComments,
        AllowTrailingCommas,
        RepeatedMembers
    ),
    promise_pure (
        impure new_mutvar(0, ColNumVar),
        Reader = json_reader(
            Stream,
            AllowComments,
            AllowTrailingCommas,
            RepeatedMembers,
            ColNumVar
        )
    ).

%-----------------------------------------------------------------------------%

get_value(Reader, Result, !State) :-
    get_token(Reader, Token, !State),
    do_get_value(Reader, Token, Result, !State).

get_object(Reader, Result, !State) :-
    get_token(Reader, Token, !State),
    % Save the context of the beginning of the value.
    make_error_context(Reader, Context, !State),
    do_get_value(Reader, Token, ValueResult, !State),
    (
        ValueResult = ok(Value),
        (
            Value = object(Members),
            Result = ok(Members)
        ;
            ( Value = null
            ; Value = bool(_)
            ; Value = string(_)
            ; Value = number(_)
            ; Value = array(_)
            ),
            Msg = "value must be an object",
            ValueDesc = value_desc(Value),
            ErrorDesc = unexpected_value(ValueDesc, yes(Msg)),
            Error = json_error(Context, ErrorDesc),
            Result = error(Error)
        )
    ;
        ValueResult = eof,
        Result = eof
    ;
        ValueResult = error(Error),
        Result = error(Error)
    ).

get_array(Reader, Result, !State) :-
    get_token(Reader, Token, !State),
    % Save the context of the beginning of the value.
    make_error_context(Reader, Context, !State),
    do_get_value(Reader, Token, ValueResult, !State),
    (
        ValueResult = ok(Value),
        (
            Value = array(Elements),
            Result = ok(Elements)
        ;
            ( Value = null
            ; Value = bool(_)
            ; Value = string(_)
            ; Value = number(_)
            ; Value = object(_)
            ),
            Msg = "value must be an array",
            ValueDesc = value_desc(Value),
            ErrorDesc = unexpected_value(ValueDesc, yes(Msg)),
            Error = json_error(Context, ErrorDesc),
            Result = error(Error)
        )
    ;
        ValueResult = eof,
        Result = eof
    ;
        ValueResult = error(Error),
        Result = error(Error)
    ).

%-----------------------------------------------------------------------------%
%
% Folding over object members.
%

object_fold(Reader, Pred, !.Acc, Result, !State) :-
    do_object_fold(Reader, Pred, !.Acc, Result, !State).

object_fold_state(Reader, Pred, !.Acc, Result, !State) :-
    do_object_fold_state(Reader, Pred, !.Acc, Result, !State).

%-----------------------------------------------------------------------------%
%
% Folding over array elements.
%

array_fold(Reader, Pred, !.Acc, Result, !State) :-
    do_array_fold(Reader, Pred, !.Acc, Result, !State).

array_fold_state(Reader, Pred, !.Acc, Result, !State) :-
    do_array_fold_state(Reader, Pred, !.Acc, Result, !State).

%-----------------------------------------------------------------------------%
%
% JSON writer.
%

:- type json.writer(Stream)
    --->    json_writer(
                json_writer_stream :: Stream,
                json_output_style  :: output_style
            ).

json.init_writer(Stream) =
    json_writer(Stream, compact).

json.init_writer(Stream, Parameters) = Writer :-
    Parameters = writer_params(OutputStyle),
    Writer = json_writer(Stream, OutputStyle).

%-----------------------------------------------------------------------------%

put_json(Writer, Value, !State) :-
    OutputStyle = Writer ^ json_output_style,
    (
        OutputStyle = compact,
        writer.raw_put_json(Writer ^ json_writer_stream, Value, !State)
    ;
        OutputStyle = pretty,
        writer.pretty_put_json(Writer ^ json_writer_stream, Value, !State)
    ).

put_comment(Writer, Comment, !State) :-
    Stream = Writer ^ json_writer_stream,
    (
        Comment = comment_eol(String),
        writer.put_eol_comment(Stream, String, !State)
    ;
        Comment = comment_multiline(String),
        writer.put_multiline_comment(Stream, String, !State)
    ).

%-----------------------------------------------------------------------------%
%
% Marshaling / Unmarshaling.
%

from_type(T) = marshal_from_type(T).
to_type(V) = unmarshal_to_type(V).

%-----------------------------------------------------------------------------%

:- pred make_unexpected_eof_error(json.reader(Stream)::in, maybe(string)::in,
    json.error(Error)::out, State::di, State::uo) is det
    <= (
        stream.line_oriented(Stream, State),
        stream.putback(Stream, char, State, Error)
    ).

make_unexpected_eof_error(Reader, MaybeMsg, Error, !State) :-
    make_error_context(Reader, Context, !State),
    Error = json_error(Context, unexpected_eof(MaybeMsg)).

:- pred make_json_error(json.reader(Stream)::in, string::in,
    json.error(Error)::out, State::di, State::uo) is det
    <= (
        stream.line_oriented(Stream, State),
        stream.putback(Stream, char, State, Error)
    ).

make_json_error(Reader, Msg, Error, !State) :-
    make_error_context(Reader, Context, !State),
    Error = json_error(Context, other(Msg)).

:- pred make_syntax_error(json.reader(Stream)::in, string::in,
    maybe(string)::in, json.error(Error)::out, State::di, State::uo)
    is det <= (
        stream.line_oriented(Stream, State),
        stream.putback(Stream, char, State, Error)
    ).

make_syntax_error(Reader, Where, MaybeMsg, Error, !State) :-
    make_error_context(Reader, Context, !State),
    Error = json_error(Context, syntax_error(Where, MaybeMsg)).

:- pred make_error_context(json.reader(Stream)::in,
    json.context::out, State::di, State::uo) is det
    <= (
        stream.line_oriented(Stream, State),
        stream.putback(Stream, char, State, Error)
    ).

make_error_context(Reader, Context, !State) :-
    promise_pure (
        Stream = Reader ^ json_reader_stream,
        stream.name(Stream, Name, !State),
        stream.get_line(Stream, LineNo, !State),
        ColNumVar = Reader ^ json_column_number,
        impure get_mutvar(ColNumVar, ColNum),
        Context = context(Name, LineNo, ColNum)
    ).

%-----------------------------------------------------------------------------%

:- instance stream.error(json.error(Error)) <= stream.error(Error) where
[
    func(error_message/1) is make_error_message
].

:- func make_error_message(json.error(Error)) = string <= stream.error(Error).

make_error_message(Error) = Msg :-
    (
        Error = stream_error(StreamError),
        Msg = stream.error_message(StreamError)
    ;
        Error = json_error(Context, ErrorDesc),
        Context = context(StreamName, LineNo, ColNo),
        (
            ErrorDesc = unexpected_eof(MaybeExtraMsg),
            (
                MaybeExtraMsg = no,
                string.format("%s:%d:%d: error: unexpected end-of-file\n",
                    [s(StreamName), i(LineNo), i(ColNo)], Msg)
            ;
                MaybeExtraMsg = yes(ExtraMsg),
                string.format("%s:%d:%d error: unexpected end-of-file: %s\n",
                    [s(StreamName), i(LineNo), i(ColNo), s(ExtraMsg)], Msg)
            )
        ;
            ErrorDesc = syntax_error(Where, MaybeExtraMsg),
            (
                MaybeExtraMsg = yes(ExtraMsg),
                string.format("%s:%d:%d: syntax error at '%s': %s\n",
                    [s(StreamName), i(LineNo), i(ColNo), s(Where), s(ExtraMsg)],
                    Msg)
            ;
                MaybeExtraMsg = no,
                string.format("%s:%d:%d: syntax error at '%s'\n",
                    [s(StreamName), i(LineNo), i(ColNo), s(Where)], Msg)
            )
        ;
            ErrorDesc = invalid_character_escape(What),
            string.format("%s:%d:%d: error: invalid character escape: '\\%c'\n",
                [s(StreamName), i(LineNo), i(ColNo), c(What)], Msg)
        ;
            ErrorDesc = other(ErrorMsg),
            string.format("%s:%d:%d: error: %s\n",
                [s(StreamName), i(LineNo), i(ColNo), s(ErrorMsg)], Msg)
        ;
            ErrorDesc = unexpected_value(What, MaybeExtraMsg),
            (
                MaybeExtraMsg = no,
                string.format("%s:%d:%d: error: unexpected %s value\n",
                    [s(StreamName), i(LineNo), i(ColNo), s(What)], Msg)
            ;
                MaybeExtraMsg = yes(ExtraMsg),
                string.format("%s:%d:%d: error: unexpected %s value: %s\n",
                    [s(StreamName), i(LineNo), i(ColNo), s(What),
                     s(ExtraMsg)], Msg)
            )
        ;
            ErrorDesc = duplicate_object_member(Name),
            string.format(
                "%s:%d:%d: error: object member \"%s\" is not unique\n",
                [s(StreamName), i(LineNo), i(ColNo), s(Name)], Msg)
        ;
            ErrorDesc = unterminated_multiline_comment,
            string.format("%s:%d:%d: error: unterminated multiline comment\n",
                [s(StreamName), i(LineNo), i(ColNo)], Msg)
        ;
            ErrorDesc = invalid_unicode_character(What),
            string.format("%s:%d:%d: error: invalid Unicode character: \\u%s\n",
                [s(StreamName), i(LineNo), i(ColNo), s(What)], Msg)
        ;
            ErrorDesc = unpaired_utf16_surrogate,
            string.format("%s:%d:%d: error: unpaired UTF-16 surrogate\n",
                [s(StreamName), i(LineNo), i(ColNo)], Msg)
        )
    ).

%-----------------------------------------------------------------------------%

:- func value_desc(json.value) = string.

value_desc(null) = "null".
value_desc(bool(_)) = "Boolean".
value_desc(string(_)) = "string".
value_desc(number(_)) = "number".
value_desc(object(_)) = "object".
value_desc(array(_)) = "array".

%-----------------------------------------------------------------------------%
%
% Stream type class instances for JSON readers.
%

% XXX these should be polymorphic in the stream state type, but unfortunately
% restrictions in the type class system mean this is not currently possible.

:- instance stream.stream(json.reader(Stream), io)
    <= stream.stream(Stream, io) where
[
    ( name(Reader, Name, !State) :-
        stream.name(Reader ^ json_reader_stream, Name, !State)
    )
].

:- instance stream.input(json.reader(Stream), io)
    <= stream.input(Stream, io) where [].

:- instance stream.reader(json.reader(Stream), json.value, io,
    json.error(Error))
    <= (
        stream.line_oriented(Stream, io),
        stream.putback(Stream, char, io, Error)
    ) where
[
    ( get(Reader, Result, !State) :-
        json.get_value(Reader, Result, !State)
    )
].

%-----------------------------------------------------------------------------%
%
% Utility predicate for (un)marshaling.
%

:- pred all_functors_have_arity_zero(type_desc::in, functor_number_lex::in,
    functor_number_lex::in) is semidet.

all_functors_have_arity_zero(TypeDesc, I, Limit) :-
    ( if I < Limit then
        get_functor(TypeDesc, I, _Name, 0, []),
        all_functors_have_arity_zero(TypeDesc, I + 1, Limit)
    else
        true
    ).

%-----------------------------------------------------------------------------%

int(I) = number(float(I)).

%-----------------------------------------------------------------------------%

is_null(null).
is_bool(bool(_)).
is_string(string(_)).
is_number(number(_)).
is_object(object(_)).
is_array(array(_)).

get_bool(bool(Bool), Bool).
get_string(string(String), String).
get_number(number(Number), Number).
get_object(object(Object), Object).
get_array(array(Array), Array).

get_int(number(Number), Int) :-
    Int = truncate_to_int(Number).

det_get_bool(Value) =
    ( if get_bool(Value, Bool)
    then Bool
    else func_error("json.det_get_bool: not a JSON Boolean")
    ).

det_get_string(Value) = 
    ( if get_string(Value, String)
    then String
    else func_error("json.det_get_string: not a JSON string")
    ).

det_get_number(Value) = 
    ( if get_number(Value, Number)
    then Number
    else func_error("json.det_get_number: not a JSON number")
    ).

det_get_object(Value) = 
    ( if get_object(Value, Object)
    then Object
    else func_error("json.det_get_object: not a JSON object")
    ).

det_get_array(Value) = 
    ( if get_array(Value, Array)
    then Array
    else func_error("json.get_array: not a JSON array")
    ).

det_get_int(Value) =
    ( if get_int(Value, Int)
    then Int
    else func_error("json.get_int: not a JSON number")
    ).

%-----------------------------------------------------------------------------%

lookup_bool(Object, Member) = Bool :-
    Value = lookup(Object, Member),
    Bool = det_get_bool(Value).

lookup_string(Object, Member) = String :-
    Value = lookup(Object, Member),
    String = det_get_string(Value).

lookup_number(Object, Member) = Number :-
    Value = lookup(Object, Member),
    Number = det_get_number(Value).

lookup_object(Object, Member) = ObjectPrime :-
    Value = lookup(Object, Member),
    ObjectPrime = det_get_object(Value).

lookup_array(Object, Member) = Array :-
    Value = lookup(Object, Member),
    Array = det_get_array(Value). 

lookup_int(Object, Member) = Int :-
    Value = lookup(Object, Member),
    Int = det_get_int(Value).

%-----------------------------------------------------------------------------%
:- end_module json.
%-----------------------------------------------------------------------------%
