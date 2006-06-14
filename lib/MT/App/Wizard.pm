# Copyright 2001-2006 Six Apart. This code cannot be redistributed without
# permission from www.movabletype.org.
#
# $Id$

package MT::App::Wizard;
use strict;

use MT::App;
@MT::App::Wizard::ISA = qw( MT::App );

sub init {
    my $app = shift;
    my %param = @_;
    eval { $app->SUPER::init(@_); };
    # ignore error in super init since we may not have the
    # database set up at this point...
    $app->{vtbl} = { };
    $app->{requires_login} = 0;
    $app->{is_admin} = 0;
    $app->{template_dir} = '';
    $app->{cgi_headers} = { };
    if ($ENV{MOD_PERL}) {
        require Apache::Request;
        $app->{apache} = $param{ApacheObject} || Apache->request;
        $app->{query} = Apache::Request->instance($app->{apache},
            POST_MAX => $app->{cfg}->CGIMaxUpload);
    } else {
        require CGI;
        $CGI::POST_MAX = $app->{cfg}->CGIMaxUpload;
        $app->{query} = CGI->new( $app->{no_read_body} ? {} : () );
    }
    $app->{cookies} = $app->cookies;
    ## Initialize the MT::Request singleton for this particular request.
    my $mt_req = MT::Request->instance;
    $mt_req->stash('App-Class', ref $app);

    $app->add_methods(pre_start => \&pre_start);
    $app->add_methods(start => \&start);
    $app->add_methods(configure => \&configure);
    $app->add_methods(optional => \&optional);
    $app->add_methods(seed => \&seed);
    $app->add_methods(complete => \&complete);
    $app->{default_mode} = 'pre_start';
    $app->{template_dir} = 'wizard';

    my $path = File::Spec->catfile($app->{mt_dir}, "images", "mt-logo.gif");
    if (!-f $path) {
        $path = File::Spec->catfile($app->{mt_dir}, "..", "mt-static", "images", "mt-logo.gif");
        $app->{cfg}->set('StaticWebPath', "../mt-static/") if -f $path;
        if (!-f $path) {
            $path = File::Spec->catfile($app->{mt_dir}, "..", "..", "mt-static", "images", "mt-logo.gif");
            $app->{cfg}->set('StaticWebPath', "../../mt-static/") if -f $path;
        }
    } else {
        $app->{cfg}->set('StaticWebPath', $app->cgipath);
    }
    if (!-f $path) {
        $path = File::Spec->catfile($app->{mt_dir}, "..", "images", "mt-logo.gif");
        $app->{cfg}->set('StaticWebPath', "../") if -f $path;
    }
    $app;
}

sub pre_start {
    my $app = shift;
    my %param;

    return$app->build_page("start.tmpl", \%param);
}

my @REQ = (
    [ 'HTML::Template', 2, 1, MT->translate('HTML::Template is required for all Movable Type application functionality.'), 'HTML Template' ],
    [ 'Image::Size', 0, 1, MT->translate('Image::Size is required for file uploads (to determine the size of uploaded images in many different formats).'), 'Image Size' ],
    [ 'File::Spec', 0.8, 1, MT->translate('File::Spec is required for path manipulation across operating systems.'), 'File Spec' ],
    [ 'CGI::Cookie', 0, 1, MT->translate('CGI::Cookie is required for cookie authentication.'), 'CGI Cookie' ],
);

my @DATA = (
    [ 'DB_File', 0, 0, MT->translate('DB_File is required if you want to use the Berkeley DB/DB_File backend.'), 'BerkeleyDB Database' ],
    [ 'DBD::mysql', 0, 0, MT->translate('DBI and DBD::mysql are required if you want to use the MySQL database backend.'), 'MySQL Database' ],
    [ 'DBD::Pg', 1.32, 0, MT->translate('DBI and DBD::Pg are required if you want to use the PostgreSQL database backend.'), 'PostgreSQL Database' ],
    [ 'DBD::SQLite', 0, 0, MT->translate('DBI and DBD::SQLite are required if you want to use the SQLite database backend.'), 'SQLite Database' ],
    [ 'DBD::SQLite2', 0, 0, MT->translate('DBI and DBD::SQLite2 are required if you want to use the SQLite2 database backend.'), 'SQLite2 Database' ],
);

my @OPT = (
    [ 'HTML::Entities', 0, 0, MT->translate('HTML::Entities is needed to encode some characters, but this feature can be turned off using the NoHTMLEntities option in mt.cfg.'), 'HTML Entities' ],
    [ 'LWP::UserAgent', 0, 0, MT->translate('LWP::UserAgent is optional; It is needed if you wish to use the TrackBack system, the weblogs.com ping, or the MT Recently Updated ping.'), 'LWP UserAgent' ],
    [ 'SOAP::Lite', 0.50, 0, MT->translate('SOAP::Lite is optional; It is needed if you wish to use the MT XML-RPC server implementation.'), 'SOAP Lite' ],
    [ 'File::Temp', 0, 0, MT->translate('File::Temp is optional; It is needed if you would like to be able to overwrite existing files when you upload.'), 'File Temp' ],
    [ 'Image::Magick', 0, 0, MT->translate('Image::Magick is optional; It is needed if you would like to be able to create thumbnails of uploaded images.'), 'ImageMagick' ],
    [ 'Storable', 0, 0, MT->translate('Storable is optional; it is required by certain MT plugins available from third parties.'), 'Storable'],
    [ 'Crypt::DSA', 0, 0, MT->translate('Crypt::DSA is optional; if it is installed, comment registration sign-ins will be accelerated.'), 'Crypt DSA'],
    [ 'MIME::Base64', 0, 0, MT->translate('MIME::Base64 is required in order to enable comment registration.'), 'MIME Base64'],
    [ 'XML::Atom', 0, 0, MT->translate('XML::Atom is required in order to use the Atom API.'), 'XML Atom'],
);

sub config_keys {
    return qw(dbname dbpath dbport dbserver dbsocket dbtype dbuser setnames mail_transfer sendmail_path smtp_server test_mail_address);
}

sub start {
    my $app = shift;
    my $q = $app->{query};

    # test for required packages...
    my ($needed) = $app->module_check(\@REQ);
    if (@$needed) {
        my %param = ( 'package_loop' => $needed );
        $param{required} = 1;
        return $app->build_page("packages.tmpl", \%param);
    }

    my ($db_missing) = $app->module_check(\@DATA);
    if ((scalar @$db_missing) == (scalar @DATA)) {
        my %param = ( 'package_loop' => $db_missing );
        $param{missing_db} = 1;
        return $app->build_page("packages.tmpl", \%param);
    }

    my ($opt_missing) = $app->module_check(\@OPT);
    push @$opt_missing, @$db_missing;
    if (@$opt_missing) {
        my %param = ( 'package_loop' => $opt_missing );
        $param{optional} = 1;
        return $app->build_page("packages.tmpl", \%param);
    }

    my %param = ( 'success' => 1 );
    return $app->build_page("packages.tmpl", \%param);
}

my %drivers = (
    'mysql' => 'DBI::mysql',
    'bdb' => 'DBM',
    'postgres' => 'DBI::postgres',
    'sqlite' => 'DBI::sqlite',
    'sqlite2' => 'DBI::sqlite'
);

sub configure {
    my $app = shift;
    my %param = @_;

    my $q = $app->{query};
    my $mode = $q->param('__mode');

    # input data unserialize to config
    %param = $app->unserialize_config;

    # get post data
    foreach ($app->config_keys) {
        $param{$_} = $q->param($_) if $q->param($_);
    }
    $param{config} = $app->serialize_config(%param);

    if (my $dbtype = $param{dbtype}) {
        $param{"dbtype_$dbtype"} = 1;
        if ($dbtype eq 'bdb') {
            $param{path_required} = 1;
        } elsif ($dbtype eq 'sqlite') {
            $param{path_required} = 1;
        } elsif ($dbtype eq 'sqlite2') {
            $param{path_required} = 1;
        } elsif ($dbtype eq 'mysql') {
            $param{login_required} = 1;
        } elsif ($dbtype eq 'postgres') {
            $param{login_required} = 1;
        }
    }

    my ($missing, $dbmod) = $app->module_check(\@DATA);
    if (scalar(@$dbmod) == 0) {
        $param{missing_db} = 1;
        $param{package_loop} = $missing;
        return $app->build_page("packages.tmpl", \%param);
    }
    foreach (@$dbmod) {
        if ($_->{module} eq 'DBD::mysql') {
            $_->{id} = 'mysql';
        } elsif ($_->{module} eq 'DBD::Pg') {
            $_->{id} = 'postgres';
        } elsif ($_->{module} eq 'DBD::SQLite') {
            $_->{id} = 'sqlite';
        } elsif ($_->{module} eq 'DBD::SQLite2') {
            $_->{id} = 'sqlite2';
        } elsif ($_->{module} eq 'DB_File') {
            $_->{id} = 'bdb';
        }
        if ($param{dbtype} && ($param{dbtype} eq $_->{id})) {
            $_->{selected} = 1;
        }
    }
    $param{db_loop} = $dbmod;

    my $ok = 1;
    my $err_msg;
    if ($app->request_method() eq 'POST' && $mode eq 'configure') {
        # if check successfully and push continue then goto next step
        if ($q->param('continue')){
            return $app->optional(\%param);
        }

        $ok = 0;
        my $dbtype = $param{dbtype};
        my $driver = $drivers{$dbtype} if exists $drivers{$dbtype};
        if ($driver) {
            my $cfg = $app->{cfg};
            $cfg->ObjectDriver($driver);
            $cfg->Database($param{dbname}) if $param{dbname};
            $cfg->DBUser($param{dbuser}) if $param{dbuser};
            $cfg->DBPassword($param{dbpass}) if $param{dbpass};
            $cfg->DBPort($param{dbport}) if $param{dbport};
            $cfg->DBSocket($param{dbsocket}) if $param{dbsocket};
            $cfg->DBHost($param{dbserver}) if $param{dbserver};
            if ($dbtype eq 'sqlite') {
                $cfg->Database($param{dbpath});
            } else {
                $cfg->DataSource($param{dbpath}) if $param{dbpath};
            }
            # test loading of object driver with these parameters...
            require MT::ObjectDriver;
            my $od = MT::ObjectDriver->new($driver);
            if (!$od) {
                $err_msg = MT::ObjectDriver->errstr;
            } else {
                $ok = 1;
            }
        }
        if ($ok) {
            $param{success} = 1;
            return $app->build_page("configure.tmpl", \%param);
        }
        $param{connect_error} = 1;
        $param{error} = $err_msg;
    }

    $app->build_page("configure.tmpl", \%param);
}

my @Sendmail = qw( /usr/lib/sendmail /usr/sbin/sendmail /usr/ucblib/sendmail );

sub optional {
    my $app = shift;
    my %param = @_;

    my $q = $app->{query};
    my $mode = $q->param('__mode');

    # input data unserialize to config
    %param = $app->unserialize_config unless %param;

    # get post data
    foreach ($app->config_keys) {
        $param{$_} = $q->param($_) if $q->param($_);
    }

    # discover sendmail
    use MT::ConfigMgr;
    my $mgr = MT::ConfigMgr->instance;
    my $sm_loc;
    for my $loc ($param{sendmail_path}, @Sendmail) {
        next unless $loc;
        $sm_loc = $loc, last if -x $loc && !-d $loc;
    }
    $param{sendmail_path} = $sm_loc || '';

    my $transfer;
    push @$transfer, {id => 'smtp', name => 'smtp'};
    push @$transfer, {id => 'sendmail', name => 'sendmail'};

    foreach(@$transfer){
        if ($_->{id} eq $param{mail_transfer}) {
            $_->{selected} = 1;
        }
    }
    
    $param{'use_'.$param{mail_transfer}} = 1;
    $param{mail_loop} = $transfer;
    $param{config} = $app->serialize_config(%param);

    my $ok = 1;
    my $err_msg;
    if ($app->request_method() eq 'POST' && $mode eq 'optional') {
        # if check successfully and push continue then goto next step
        if ($q->param('continue')){
            return $app->seed(%param);
        }

        $ok = 0;
        if ($param{test_mail_address}){
            my $cfg = $app->{cfg};
            $cfg->MailTransfer($param{mail_transfer}) if $param{mail_transfer};
            $cfg->SMTPServer($param{smtp_server}) if $param{smtp_server};
            $cfg->SendMailPath($param{sendmail_path}) if $param{sendmail_path};
            my %head = (To => $param{test_mail_address},
                        From => $cfg->EmailAddressMain || $param{test_mail_address},
                        Subject => $app->translate("Test mail from Configuration Wizard") );
            my $charset = $cfg->PublishCharset || 'iso-8859-1';
            $head{'Content-Type'} = qq(text/plain; charset="$charset");

            my $body = $app->translate("test test test. change me please");

            require MT::Mail;
            $ok = MT::Mail->send(\%head, $body);

            if ($ok){
                $param{success} = 1;
                return $app->build_page("optional.tmpl", \%param);
            }else{
                $err_msg = MT::Mail->errstr;
            }
        }
        

        $param{send_error} = 1;
        $param{error} = $err_msg;
    }

    $app->build_page("optional.tmpl", \%param);
}

sub seed {
    my $app = shift;
    my %param = @_;

    my $q = $app->{query};
    my $mode = $q->param('__mode');

    $param{static_web_path} = $app->{cfg}->get('StaticWebPath');
    $param{cgi_path} = $app->cgipath; # no more mt-wizard.cgi

    if (my $dbtype = $q->param('dbtype')) {
        if ($dbtype eq 'bdb') {
            $param{use_bdb} = 1;
            $param{database_name} = $q->param('dbpath');
        } elsif ($dbtype eq 'sqlite') {
            $param{use_sqlite} = 1;
            $param{OBJECT_DRIVER} = 'DBI::sqlite';
            $param{database_name} = $q->param('dbpath');
        } elsif ($dbtype eq 'sqlite2') {
            $param{use_sqlite} = 1;
            $param{use_sqlite2} = 1;
            $param{OBJECT_DRIVER} = 'DBI::sqlite';
            $param{database_name} = $q->param('dbpath');
        } elsif ($dbtype eq 'mysql') {
            $param{use_dbms} = 1;
            $param{object_driver} = 'dbi::mysql';
            $param{database_name} = $q->param('dbname');
            $param{database_username} = $q->param('dbuser');
            $param{database_password} = $q->param('dbpass') if $q->param('dbpass');
            $param{database_host} = $q->param('dbserver') if $q->param('dbserver');
            $param{database_port} = $q->param('dbport') if $q->param('dbport');
            $param{database_socket} = $q->param('dbsocket') if $q->param('dbsocket');
            $param{use_setnames} =  $q->param('setnames') if $q->param('setnames');
        } elsif ($dbtype eq 'postgres') {
            $param{use_dbms} = 1;
            $param{object_driver} = 'dbi::postgres';
            $param{database_name} = $q->param('dbname');
            $param{database_username} = $q->param('dbuser');
            $param{database_password} = $q->param('dbpass') if $q->param('dbpass');
            $param{database_host} = $q->param('dbserver') if $q->param('dbserver');
            $param{database_port} = $q->param('dbport') if $q->param('dbport');
            $param{use_setnames} =  $q->param('setnames') if $q->param('setnames');
        }
    }

    if ($app->{cfg}->MailTransfer ne $q->param('mail_transfer')) {
        $param{mail_transfer} = $q->param('mail_transfer');
    }

    if ($app->{cfg}->SMTPServer ne $q->param('smtp_server')) {
        $param{smtp_server} = $q->param('smtp_server');
    }

    if ($app->{cfg}->SendMailPath ne $q->param('sendmail_path')) {
        $param{sendmail_path} = $q->param('sendmail_path');
    }

    return $app->build_page("complete.tmpl", \%param);
}

sub serialize_config {
    my $app = shift;
    my %param = @_;
 
    require MT::Serialize;
    my $ser = MT::Serialize->new('MT');
    my @keys = $app->config_keys();
    my %set = map { $_ => $param{$_} } @keys;
    my $set = \%set;
    unpack 'H*', $ser->serialize(\$set);
}

sub unserialize_config {
    my $app = shift;
    my $data = $app->{query}->param('config');
    my %config = { };
    if ($data) {
        $data = pack 'H*', $data;
        require MT::Serialize;
        my $ser = MT::Serialize->new('MT');
        my $thawed = $ser->unserialize($data);
#        use Data::Dumper;
#        die Dumper($thawed);
        if ($thawed) {
            my $saved_cfg = $$thawed;
            if (keys %$saved_cfg) {
                $config{$_} =  $saved_cfg->{$_} foreach keys %$saved_cfg;
            }
        }
    }
    %config;
}

sub cgipath {
    my $app = shift;

    # these work for Apache... need to test for IIS...
    my $host = $ENV{HTTP_HOST};
    my $port = $ENV{SERVER_PORT};
    my $uri = $ENV{REQUEST_URI};
    $uri =~ s/mt-wizard(\.cgi)?.*$//;

    my $cgipath = '';
    $cgipath = $port == 443 ? 'https' : 'http';
    $cgipath .= '://' . $host;
    $cgipath .= ($port == 443 || $port == 80) ? '' : ':' . $port;
    $cgipath .= $uri;

    $cgipath;
}
sub module_check {
    my $self = shift;
    my $modules = shift;
    my (@missing, @ok);
    foreach my $ref (@$modules) {
        my($mod, $ver, $req, $desc, $name) = @$ref;
        eval("use $mod" . ($ver ? " $ver;" : ";"));
        if ($@) {
            push @missing, { module => $mod,
                             version => $ver,
                             required => $req,
                             description => $desc,
                             name => $name };
        } else {
            push @ok, { module => $mod,
                        version => $ver,
                        required => $req,
                        description => $desc,
                        name => $name };
        }
    }
    (\@missing, \@ok);
}

1;

=pod
 * Tests Connetionから戻ったときにSQLSetNamesのチェックが外れている件
 * mt-config.cgiが書き込めるようなら書き込んでしまう
 * 全般的にキレイに
 * Invalid Mail address のチェック＆メッセージ
 * Mail TestのSuccessメッセージ
 * Mail設定のconfigへの反映
=cut
