<?php
# Movable Type (r) Open Source (C) 2001-2009 Six Apart, Ltd.
# This program is distributed under the terms of the
# GNU General Public License, version 2.
#
# $Id$

function smarty_function_mtblogcommentcount($args, &$ctx) {
    $args['blog_id'] = $ctx->stash('blog_id');
    $count = $ctx->mt->db->blog_comment_count($args);
    return $ctx->count_format($count, $args);
}
