/*  $Id$

    Part of SWI-Prolog RDF parser

    Author:  Jan Wielemaker
    E-mail:  jan@swi.psy.uva.nl
    WWW:     http://www.swi.psy.uva.nl/projects/SWI-Prolog/
    Copying: LGPL-2.  See the file COPYING or http://www.gnu.org

    Copyright (C) 1990-2000 SWI, University of Amsterdam. All rights reserved.
*/

:- module(rdf,
	  [ load_rdf/2,			% +File, -Triples
	    load_rdf/3,			% +File, -Triples, +Options
	    xml_to_rdf/3,		% +XML, +BaseURI, -Triples
	    process_rdf/3		% +File, +BaseURI, :OnTriples
	  ]).

:- meta_predicate(process_rdf(+, +, :)).

:- use_module(library(sgml)).		% Basic XML loading
:- use_module(rdf_parser).		% Basic parser
:- use_module(rdf_triple).		% Generate triples

%	load_rdf(+File, -Triples[, +Options])
%
%	Parse an XML file holding an RDF term into a list of RDF triples.
%	see rdf_triple.pl for a definition of the output format.

load_rdf(File, Triples) :-
	load_rdf(File, Triples, []).

load_rdf(File, Triples, Options) :-
	option(base_uri(BaseURI), Options, []),
	load_structure(File,
		       [ RDFElement
		       ],
		       [ dialect(xmlns)
		       ]),
	xml_to_rdf(RDFElement, BaseURI, Triples).

	
%	xml_to_rdf(+XML, +BaseURI, -Triples)

xml_to_rdf(XML, BaseURI, Triples) :-
	xml_to_plrdf(XML, BaseURI, RDF),
	rdf_triples(RDF, Triples).


		 /*******************************
		 *	     BIG FILES		*
		 *******************************/

:- dynamic
	in_rdf/0,
	object_handler/2.

process_rdf(File, BaseURI, OnObject) :-
	retractall(rdf:in_rdf),
	strip_module(OnObject, Module, Pred),
	asserta(rdf:object_handler(BaseURI, Module:Pred), Ref),
	open(File, read, In, [type(binary)]),
	new_sgml_parser(Parser, []),
	set_sgml_parser(Parser, file(File)),
	set_sgml_parser(Parser, dialect(xmlns)),
	sgml_parse(Parser,
		   [ source(In),
		     call(begin, rdf:on_begin),
		     call(end, rdf:on_end)
		   ]),
	close(In),
	erase(Ref).

on_end(NS:'RDF', _) :-
	rdf_name_space(NS),
	retractall(in_rdf).

on_begin(NS:'RDF', _, _) :-
	rdf_name_space(NS),
	assert(in_rdf).
on_begin(Tag, Attr, Parser) :-
	in_rdf, !,
	sgml_parse(Parser,
		   [ document(Content),
		     parse(content)
		   ]),
	object_handler(BaseURI, OnTriples),
	xml_to_rdf(element(Tag, Attr, Content), BaseURI, Tripples),
	call(OnTriples, Tripples).


		 /*******************************
		 *	      UTIL		*
		 *******************************/

%	option(Option(?Value), OptionList, Default)

option(Opt, Options) :-
	memberchk(Opt, Options), !.
option(Opt, Options) :-
	functor(Opt, OptName, 1),
	arg(1, Opt, OptVal),
	memberchk(OptName=OptVal, Options), !.

option(Opt, Options, _) :-
	option(Opt, Options), !.
option(Opt, _, Default) :-
	arg(1, Opt, Default).
