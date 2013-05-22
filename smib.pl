#!/usr/bin/perl

use strict;
use warnings;

use POE qw(Component::IRC);
use IPC::System::Simple qw(capture);
use String::Escape qw(printable);

my $nickname = 'smibtest';
my $ircname  = 'So Make It Bot';
my $programsdir = '/home/xbmc/irccat-commands/';
my $server   = 'holmes.freenode.net';
my @channels = ('#smibtest');
# Flood control is built in, defauts for now.
# Use perldoc POE::Component::IRC if you want
# to configure it.

#create a new POE-IRC object
my $irc = POE::Component::IRC->spawn(nick    => $nickname,
                                     ircname => $ircname,
                                     server  => $server,
) or die "Cannot make POE-IRC object: $!";

POE::Session->create(package_states => [main => [ qw(_default _start irc_001 irc_public irc_msg) ],],
                     heap           => { irc => $irc },);

#and start it
$poe_kernel->run();

sub timestamp {
  my $time = `date`;
  chomp $time;
  return "$time ";
}

sub _start {
  my $heap = $_[HEAP];

  # retrieve our component's object from the heap where we stashed it
  my $irc = $heap->{irc};

  $irc->yield( register => 'all' );
  $irc->yield( connect => { } );
  return;
}

sub irc_001 {
  my $sender = $_[SENDER];

  # Since this is an irc_* event, we can get the component's object by
  # accessing the heap of the sender. Then we register and connect to the
  # specified server.
  my $irc = $sender->get_heap();

  print "Connected to ", $irc->server_name(), "\n";

  # we join our channels
  $irc->yield( join => $_ ) for @channels;
  return;
}

# like when someone says somthing in a channel
sub irc_public {
  my ($sender, $who, $where, $what) = @_[SENDER, ARG0 .. ARG2];
  my $nick = ( split /!/, $who )[0];
  my $channel = $where->[0];

  #this launches ?commands said in a channel
  my @output;
  if ($what =~ m/^\?(\w+) {0,1}(.*)/) {
    print &timestamp . "Caught irc_public as ?command channel: '$channel' who: '$who' what: '$what'\n";

    #damn it Benjie I told you file extensions were daft, now I have to do more work
    my $command = $1;
    my @commands;
    eval {
      @commands = capture('find', "$programsdir", '-type', 'f', '-name', "$command\.*");
    };
    if ($@) {
      print "You probably set \$programsdir wrong: $@\n";
    }
    if (@commands < 1) {
      $irc->yield( privmsg => $channel  => "Sorry $nick, I don't have a $command command." );
      return;
    }
    #now we have an array of valid commands, pick one.
    my $runcommand = shift @commands;
    chomp $runcommand;

    # Take what the user typed after the command less the space and escape what we need to.
    # This is not a security feature.
    my $argline = printable($2);

    # the scripts need their working directory to be the programsdir
    # we probably don't ever need another working directory
    chdir $programsdir; 

    # now we run the command, caprure() will NOT invoke a shell if it is called with
    # more than one argument. We need to eval this, or we will exit if the command
    # returns non zero status.
    eval {
      @output = capture("$runcommand", "$nick", "$channel", "$channel", "$argline");
    };
    if ($@) {
      $irc->yield( privmsg => $channel => "Sorry $nick, $command is on fire." );
    }
  }
  for my $line (@output) {
    $irc->yield( privmsg => $channel => $line );
  }

  #TODO we need to at least check for user pownces at least here

  return;
}

# like when someone says somthing with /msg us
sub irc_msg {
  my ($sender, $who, $where, $what) = @_[SENDER, ARG0 .. ARG2];
  my $nick = ( split /!/, $who )[0];
  my $channel = $where->[0];

  #this launches ?commands said in PM to us, we reply via PM
  my @output;
  if ($what =~ m/^\?(\w+) {0,1}(.*)/) {
    print &timestamp . "Caught irc_msg as ?command channel: '$channel' who: '$who' what: '$what'\n";

    #find sctips with extensions
    my $command = $1;
    my @commands;
    eval {
      @commands = capture('find', "$programsdir", '-type', 'f', '-name', "$command\.*");
    };
    if ($@) {
      print "You probably set \$programsdir wrong: $@\n";
    }
    if (@commands < 1) {
      $irc->yield( privmsg => $nick => "Sorry, I don't have a $command command." );
      return;
    }
    #now we have an array of valid commands, pick one.
    my $runcommand = shift @commands;
    chomp $runcommand;

    # Take what the user typed after the command less the space and escape what we need to.
    # This is not a security feature.
    my $argline = printable($2);

    # the scripts need their working directory to be the programsdir
    # we probably don't ever need another working directory
    chdir $programsdir;

    # now we run the command, caprure() will NOT invoke a shell if it is called with
    # more than one argument. We need to eval this, or we will exit if the command
    # returns non zero status. This is a big legacy to emulate old smib, $where->[1]
    # and up might be the RightWay (tm) to produce 'null'.
    eval {
      @output = capture("$runcommand", "$nick", 'null', "$nick", "$argline"); 
    };
    if ($@) {
      $irc->yield( privmsg => $nick => "Sorry, $command is on fire." );
    }
  }
  for my $line (@output) {
    $irc->yield( privmsg => $nick => $line );
  }
  return;
}

# This will catch everything we don't and offer clues about what we should catch
sub _default {
   my ($event, $args) = @_[ARG0 .. $#_];
   my @output = ( "$event: " );

  for my $arg (@$args) {
    if ( ref $arg eq 'ARRAY' ) {
       push( @output, '[' . join(', ', @$arg ) . ']' );
    }
    else {
      push ( @output, "'$arg'" );
    }
  }
  print join ' ', @output, "\n";
  return;
}
