#!/usr/bin/perl

use strict;
use warnings;

use POE qw(Component::IRC);
use IPC::System::Simple qw(capture);
use String::Escape qw(printable);

my $nickname = 'smib';
my $ircname  = 'So Make It Bot';
my $programsdir = '/home/irccat/scripts/';
my $server   = 'holmes.freenode.net';
my @channels = ('#smibtest', '#southackton', '#somakeit');
# Flood control is built in, defauts for now.
# Use perldoc POE::Component::IRC if you want
# to configure it.

#this maintains a list of commands we can use
my $all_commands = {};
my $commands_time = 0;
sub update_commands {
  opendir DIRHANDLE, $programsdir or die "Can't open programs direstory '$programsdir'";
  if ((stat(DIRHANDLE))[9] > $commands_time) {
    #build the hashref, the last command.ext will take the command.
    for (keys %$all_commands) {
      delete $all_commands->{$_};
    }

    while (my $file = readdir(DIRHANDLE)) {
      if (! -f "$programsdir/$file" or ! -x "$programsdir/$file") {
        # this one is either a directory or not executable
        next;
      }
      if ($file =~ m/(\w+)\.\w+/) {
        $all_commands->{$1} = $programsdir . '/' . $file;
      } else {
        print STDERR "Can't parse command '$programsdir' '$file'\n";
        next;
      }
    }
    
    #mark list as up to date
    $commands_time = (stat(DIRHANDLE))[9]; 
    print "Updated ?commands hash\n";
  }
  closedir DIRHANDLE;
  return;
}
#run this once at startup;
&update_commands;

#create a new POE-IRC object
my $irc = POE::Component::IRC->spawn(nick    => $nickname,
                                     ircname => $ircname,
                                     server  => $server,
) or die "Cannot make POE-IRC object: $!";

POE::Session->create(package_states => [main => [ qw(_default _start irc_001 irc_public irc_msg) ],],
                     heap           => { irc => $irc },);

#and finally, start it
$poe_kernel->run();

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

  print 'Connected to ', $irc->server_name(), "\n";

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
    print "Caught irc_public as ?command channel: '$channel' who: '$who' what: '$what'\n";
    
    my $command = $1;

    #update the list of programs
    &update_commands;

    #see if the command exists
    if (!$all_commands->{$command}) {
      $irc->yield( privmsg => $channel  => "Sorry $nick, I don't have a $command command." );
      return;
    }

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
      @output = capture($all_commands->{$command}, $nick, $channel, $channel, $argline);
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
    print "Caught irc_msg as ?command channel: '$channel' who: '$who' what: '$what'\n";

    my $command = $1;

    #update the list of programs
    &update_commands;

    #see if the command exists
    if (!$all_commands->{$command}) {
      $irc->yield( privmsg => $channel  => "Sorry, I don't have a $command command." );
      return;
    }

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
      @output = capture($all_commands->{$command}, $nick, 'null', $nick, $argline);
    };
    if ($@) {
      $irc->yield( privmsg => $channel => "Sorry, $command is on fire." );
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
  print ' ';
  print join ' ', @output, "\n";
  return;
}
