# Movable Type (r) Open Source (C) 2001-2008 Six Apart, Ltd.
# This program is distributed under the terms of the
# GNU General Public License, version 2.
#
# $Id$

package MT::ArchiveType::AuthorMonthly;

use strict;
use base qw( MT::ArchiveType::Author MT::ArchiveType::Monthly );
use MT::Util qw( dirify start_end_month );

sub name {
    return 'Author-Monthly';
}

sub archive_label {
    return MT->translate('AUTHOR-MONTHLY_ADV');
}

sub default_archive_templates {
    return [
        {
            label    => 'author-display-name/yyyy/mm/index.html',
            template => '%-a/%y/%m/%f',
            default  => 1
        },
        {
            label    => 'author_display_name/yyyy/mm/index.html',
            template => '%a/%y/%m/%f'
        },
    ];
}

sub dynamic_template {
    return 'author/<$MTEntryAuthorID$>/<$MTArchiveDate format="%Y%m"$>';
}

sub template_params {
    return {
        archive_class                    => "author-monthly-archive",
        author_monthly_archive           => 1,
        'module_author-monthly_archives' => 1,
        main_template                    => 1,
        archive_template                 => 1,
        archive_listing                  => 1,
    };
}

sub archive_title {
    my $obj = shift;
    my ( $ctx, $entry_or_ts ) = @_;
    my $stamp = ref $entry_or_ts ? $entry_or_ts->authored_on : $entry_or_ts;
    my ($start) = start_end_month($stamp);
    my $date =
      MT::Template::Context::_hdlr_date( $ctx,
        { ts => $start, 'format' => "%B %Y" } );
    my $author = $obj->display_name($ctx);

    sprintf( "%s%s", $author, $date );
}

sub archive_file {
    my $obj = shift;
    my ( $ctx, %param ) = @_;
    my $timestamp = $param{Timestamp};
    my $file_tmpl = $param{Template};
    my $author    = $ctx->{__stash}{author};
    my $entry     = $ctx->{__stash}{entry};
    my $file;
    my $this_author = $author ? $author : ( $entry ? $entry->author : undef );
    return "" unless $this_author;
    my $name = dirify( $this_author->nickname );

    if ( $name eq '' || !$file_tmpl ) {
        return "" unless $this_author;
        $name = "author" . $this_author->id if $name !~ /\w/;
        my ($start) = start_end_month($timestamp);
        my ( $year, $month ) = unpack 'A4A2', $start;
        $file = sprintf( "%s/%04d/%02d/index", $name, $year, $month );
    }
    else {
        ( $ctx->{current_timestamp}, $ctx->{current_timestamp_end} ) =
          start_end_month($timestamp);
    }
    $file;
}

sub archive_group_iter {
    my $obj = shift;
    my ( $ctx, $args ) = @_;
    my $blog = $ctx->stash('blog');
    my $sort_order =
      ( $args->{sort_order} || '' ) eq 'ascend' ? 'ascend' : 'descend';
    my $auth_order = $args->{sort_order} ? $args->{sort_order} : 'ascend';
    my $order = ( $sort_order eq 'ascend' ) ? 'asc' : 'desc';
    my $limit = exists $args->{lastn} ? delete $args->{lastn} : undef;

    my $tmpl  = $ctx->stash('template');
    my @data  = ();
    my $count = 0;

    my $at       = $ctx->{archive_type};
    my $archiver = MT->publisher->archiver($at);
    my $author;

    my $ts    = $ctx->{current_timestamp};
    my $tsend = $ctx->{current_timestamp_end};

    # if (($tmpl && $tmpl->type ne 'index') &&
    #     ($archiver && $archiver->author_based))
    # {
    $author = $ctx->stash('author');

    # }

    require MT::Entry;
    my $loop_sub = sub {
        my $auth       = shift;
        my $count_iter = MT::Entry->count_group_by(
            {
                blog_id   => $blog->id,
                author_id => $auth->id,
                status    => MT::Entry::RELEASE(),
                ( $ts && $tsend ? ( authored_on => [ $ts, $tsend ] ) : () ),
            },
            {
                ( $ts && $tsend ? ( range_incl => { authored_on => 1 } ) : () ),
                group => [
                    "extract(year from authored_on)",
                    "extract(month from authored_on)"
                ],
                'sort' => "extract(year from authored_on) $order,
                         extract(month from authored_on) $order"
            }
        ) or return $ctx->error("Couldn't get monthly archive list");

        while ( my @row = $count_iter->() ) {
            my $hash = {
                year   => $row[1],
                month  => $row[2],
                author => $auth,
                count  => $row[0],
            };
            push( @data, $hash );
            return $count + 1
              if ( defined($limit) && ( $count + 1 ) == $limit );
            $count++;
        }
        return $count;
    };

    # Count entry by author
    if ($author) {
        $loop_sub->($author);
    }
    else {

        # load authors
        require MT::Author;
        my $iter;
        $iter = MT::Author->load_iter(
            undef,
            {
                sort      => 'name',
                direction => $auth_order,
                join      => [
                    'MT::Entry', 'author_id',
                    { status => MT::Entry::RELEASE(), blog_id => $blog->id },
                    { unique => 1 }
                ]
            }
        );

        while ( my $a = $iter->() ) {
            $loop_sub->($a);
            last if ( defined($limit) && $count == $limit );
        }
    }

    my $loop = @data;
    my $curr = 0;

    return sub {
        if ( $curr < $loop ) {
            my $date = sprintf(
                "%04d%02d%02d000000",
                $data[$curr]->{year},
                $data[$curr]->{month}, 1
            );
            my ( $start, $end ) = start_end_month($date);
            my $count = $data[$curr]->{count};
            my %hash  = (
                author => $data[$curr]->{author},
                year   => $data[$curr]->{year},
                month  => $data[$curr]->{month},
                start  => $start,
                end    => $end
            );
            $curr++;
            return ( $count, %hash );
        }
        undef;
      }
}

sub archive_group_entries {
    my $obj = shift;
    my ( $ctx, %param ) = @_;
    Carp::confess("ctx is undef") unless defined $ctx;
    my $ts =
        $param{year}
    ? sprintf( "%04d%02d%02d000000", $param{year}, $param{month}, 1 )
        : $ctx->stash('current_timestamp');
    my $author = $param{author} || $ctx->stash('author');
    my $limit = $param{limit};
    $obj->dated_author_entries( $ctx, 'Author-Monthly', $author, $ts, $limit );
}

sub archive_entries_count {
    my $obj = shift;
    my ( $blog, $at, $entry ) = @_;
    my $auth = $entry->author;
    return $obj->SUPER::archive_entries_count(
        {
            Blog        => $blog,
            ArchiveType => $at,
            Timestamp   => $entry->authored_on,
            Author      => $auth
        }
    );
}

1;