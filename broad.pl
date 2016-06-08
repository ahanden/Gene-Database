#!/usr/bin/env perl

use strict;
use warnings;
use IO::Handle;
STDOUT->autoflush(1);


sub main {
    my $updater = myUpdate->new(usage => "Usage: perl broad.pl [pathways.gmt]");
    $updater->update(); 
}


{
    package myUpdate;
    use base ("Update");
    use Getopt::Long;

    sub checkArgs {
        my $self = shift;

        $self->{eid_cache} = {};

        my ($verbose, $db, $user, $password, $species, $cnf_file);
        if(GetOptions('verbose' => \$verbose,
                'database=s' => \$db,
                'username=s' => \$user,
                'password=s' => \$password,
                'cnf_file=s' => \$cnf_file)  && @ARGV == 1) {
            $self->{fname}      = $ARGV[0];
            $self->{verbose}    = $verbose ? $verbose : 0;
            $self->{dbname}     = $db;
            $self->{user}       = $user;
            $self->{password}   = $password;
            $self->{cnf_file}   = $cnf_file;

            return 1;
        }
        return 0;
    }
   
    sub getEIDs {
        my ($self, $eid) = @_;
        if(!exists($self->{eid_cache}->{$eid})) {
            my @eids;

            $self->{valid_eid_query}->execute($eid);
            if($self->{valid_eid_query}->fetch()->[0]) {
                push(@eids, $eid);
            }

            if(!@eids) {
                $self->{discontinued_query}->execute($eid);
                while(my $ref = $self->{discontinued_query}->fetch()) {
                    push(@eids, $ref->[0]);
                }
            }

            $self->{eid_cache}->{$eid} = \@eids;

        }
        return @{$self->{eid_cache}->{$eid}};
    }

    sub exec_main {
        my $self = shift;

        open my $IN, '<', $self->{fname} or die "Failed to open $self->{fname}: $!\n";

        my $wc = `wc -l $self->{fname}`;
        my ($total) = $wc =~ /(^\d+)/;
        $self->{prog_total} = $total;

        $self->{valid_eid_query}    = $self->{dbh}->prepare("SELECT EXISTS(SELECT * FROM genes WHERE entrez_id = ?)");
        $self->{discontinued_query} = $self->{dbh}->prepare("SELECT entrez_id FROM discontinued_genes WHERE discontinued_id = ?");

        my $insert_query = $self->{dbh}->prepare("INSERT IGNORE INTO annotations (entrez_id, annotation, db) VALUES (?, ?, ?)");

        while (my $line = <$IN>) {
            $self->logProgress();
            chomp $line;
            my @genes = split(/\t/,$line);

            my $annotation = shift @genes;
            my $url        = shift @genes;

            my ($db) = $annotation =~ /(.*?)_/;
            $annotation =~ s/(.*?)_//;

            foreach my $gene(@genes) {
                foreach my $eid($self->getEIDs($gene)) {
                    $insert_query->execute($eid, $annotation, $db);
                }
            }
        }
        close $IN;
        $self->log("\n");
    }
}

main();
