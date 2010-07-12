# vim: sw=4 : ts=4 : et
use warnings;
use strict;

use Test::More tests => 13;
use Test::LongString;

use POSIX ();
use File::Temp qw( tempdir );
use Data::Dumper;
use File::Slurp;

use Munin::Node::SpoolReader;
use Munin::Node::SpoolWriter;


### new
{
    my $dir = POSIX::getcwd();

    my $writer = new_ok('Munin::Node::SpoolReader' => [
        spooldir => $dir,
    ], 'spooldir provided to constructor');

    is($writer->{spooldir}, $dir, 'spooldir key is set');
    ok( -d $writer->{spooldirhandle}, 'spooldirhandle refers to a directory');
}
{
    eval { Munin::Node::SpoolReader->new(fnord => 'blort') };
    like($@, qr/./, 'Dies if no spooldir provided');
}


### fetch
{
        my $dir = tempdir( CLEANUP => 1 );
        my $writer = Munin::Node::SpoolWriter->new(spooldir => $dir);
        my $reader = Munin::Node::SpoolReader->new(spooldir => $dir);

        # write some data
        $writer->write(1234567890, 'fnord', [
            'graph_title CPU usage',
            'system.label system',
            'system.value 1',
        ]);

        $writer->write(1234567900, 'fnord', [
            'graph_title CPU usage',
            'system.label system',
            'system.value 2',
        ]);

        $writer->write(1234567910, 'fnord', [
            'graph_title CPU usage',
            'system.label system',
            'system.value 3',
        ]);

        is_string($reader->fetch(1234567899), <<EOS, 'Fetched data since the write');
multigraph fnord
graph_title CPU usage
system.label system
system.value 1234567900:2
multigraph fnord
graph_title CPU usage
system.label system
system.value 1234567910:3
EOS

        is_string($reader->fetch(1234567900), <<EOS, 'Start timestamp is not inclusive');
multigraph fnord
graph_title CPU usage
system.label system
system.value 1234567910:3
EOS

        is_string($reader->fetch(1), <<EOS, 'Timestamp predates all result: all results are returned');
multigraph fnord
graph_title CPU usage
system.label system
system.value 1234567890:1
multigraph fnord
graph_title CPU usage
system.label system
system.value 1234567900:2
multigraph fnord
graph_title CPU usage
system.label system
system.value 1234567910:3
EOS

        is_string($reader->fetch(1234567911), '', 'Timestamp postdates the last result: empty string');
}
{
        my $dir = tempdir( CLEANUP => 1 );
        my $writer = Munin::Node::SpoolWriter->new(spooldir => $dir);
        my $reader = Munin::Node::SpoolReader->new(spooldir => $dir);

        # write some data
        $writer->write(1234567890, 'fnord', [
            'graph_title CPU usage',
            'system.label system',
            '',
            'system.value 1',
            '',
        ]);

        is_string($reader->fetch(1), <<EOS, 'Blank lines are ignored');
multigraph fnord
graph_title CPU usage
system.label system
system.value 1234567890:1
EOS

}


### _get_spooled_plugins
### list
{
        my $dir = tempdir( CLEANUP => 1 );
        my $writer = Munin::Node::SpoolWriter->new(spooldir => $dir);
        my $reader = Munin::Node::SpoolReader->new(spooldir => $dir);

        is_deeply([ sort $reader->_get_spooled_plugins ], [], 'No spooled plugins to list');
        is($reader->list, "\n", 'No spooled plugins to list');

        # write "results" for several plugins
        $writer->write(1234567890, 'fnord', [
            'graph_title CPU usage',
            'system.label system',
            'system.value 1',
        ]);
        $writer->write(1234567890, 'floop', [
            'graph_title Memory usage',
            'system.label system',
            'system.value 3.14',
        ]);
        $writer->write(1234567890, 'blort', [
            'graph_title Flux capacitance',
            'system.label system',
            'system.value -4',
        ]);

        is_deeply([ sort $reader->_get_spooled_plugins ], [ sort qw( fnord floop blort ) ], 'Retrieved list of spooled plugins');
        is($reader->list, "blort floop fnord\n", 'Retrieved stringified list of spooled plugins');
}
