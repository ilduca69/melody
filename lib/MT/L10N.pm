# Copyright 2001-2006 Six Apart. This code cannot be redistributed without
# permission from www.sixapart.com.  For more information, consult your
# Movable Type license.
#
# $Id$

package MT::L10N;
use strict;
use Locale::Maketext;

@MT::L10N::ISA = qw( Locale::Maketext );
@MT::L10N::Lexicon = (
    _AUTO => 1,
);

sub language_name {
    my $tag = $_[0]->language_tag;
    require I18N::LangTags::List;
    I18N::LangTags::List::name($tag);
}

sub encoding { 'iso-8859-1' }   ## Latin-1
sub ascii_only { 0 }

1;
