#!/usr/bin/perl

use strict;
use warnings;

use POE qw(Component::IRC Component::IRC::Plugin::Connector Component::IRC::Plugin::NickServID);
use IPC::System::Simple qw(capture);
use POE qw(Component::Server::TCP);

my $nickname    = 'smib';
my $password    = 'do_not_check_me_in';
my $ircname     = 'So Make It Bot';
my $programsdir = '/home/smib/smib-commands/';
my $server      = 'chat.freenode.net';
#the first channel is the default channel for messages recieved via TCP etc.
my @channels    = ('#somakeit', '#smibtest', '#southackton');
my $listen_port = '1337';
# Flood control is built in, defauts for now.
# Use perldoc POE::Component::IRC if you want
# to configure it.

# this function builds a list of valid commands/programs within a directory,
# it will be run several times for different kinds of command
sub get_commands_by_dir {
  my $base_dir = shift;		#directory to search
  my $updated_time = shift;	#reference to last time directory was searched
  my $commands_ref = shift;	#reference to hash of commands

  opendir DIRHANDLE, $base_dir or return 0; #bad status
  if ((stat(DIRHANDLE))[9] > $$updated_time) {
    #the directory has been changed, clear the hash and build a new one
    for (keys %$commands_ref) {
      delete $commands_ref->{$_};
    }

    while (my $file = readdir(DIRHANDLE)) {
      if (! -f "$base_dir/$file" or ! -x "$base_dir/$file") {
        #this is either a directory or non-executable file
        next;
      }
      if ($file =~ m/(\w+).\w+/) {
        #this file is executable and has an extension
        $commands_ref->{$1} = $base_dir . '/' . $file;
      } else {
        print STDERR "Can't parse command '$base_dir' '$file'\n";
        next;
      }
    }

    #mark the list as updated
    $$updated_time = (stat(DIRHANDLE))[9];
    print "Updated commands hash for '$base_dir'.\n";
  }
  closedir DIRHANDLE;
  return 1; #good status
}

my $all_commands = {};
my $all_commands_time = 0;
&get_commands_by_dir($programsdir, \$all_commands_time, $all_commands) or die "No programsdir, you need one of those.\n";

my $log_commands = {};
my $log_commands_time = 0;
&get_commands_by_dir("$programsdir/log", \$log_commands_time, $log_commands) or print "No log directory in programsdir.\n";

#create a new POE-IRC object
my $irc = POE::Component::IRC->spawn(nick    => $nickname,
                                     ircname => $ircname,
                                     server  => $server,
) or die "Cannot make POE-IRC object: $!";

# For debug, add _default to the list of evernts to catch, it can show what event your new feature might
# want to use. Do the thing in IRC then view the log.
POE::Session->create(package_states => [main => [ qw(_start irc_001 irc_public irc_msg lag_o_meter) ],],
                     heap           => { irc => $irc },);

# Now we're ready to run IRC, set up a TCP server to listen on a port for stuff to say
POE::Component::Server::TCP->new(
  Port        => $listen_port,
  ClientInput => \&listen_port_handler); 

#and finally, start the POE kernel
$poe_kernel->run();

sub _start {
  my $heap = $_[HEAP];

  # retrieve our component's object from the heap where we stashed it
  my $irc = $heap->{irc};

  $irc->yield( register => 'all' );

  # load the connector plugin to re-connect us whenever
  $heap->{connector} = POE::Component::IRC::Plugin::Connector->new();
  $irc->plugin_add( 'Connector' => $heap->{connector} );

  # load the nickservid plugin, it registers with nickserv whenever
  $irc->plugin_add( 'NickServID', POE::Component::IRC::Plugin::NickServID->new( Password => $password ));

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
    
    my $lcasecmd = $1;
    $lcasecmd =~ tr/A-Z/a-z/;
    my $argline = $2;

    #update the list of programs
    &get_commands_by_dir($programsdir, \$all_commands_time, $all_commands) or print STDERR "Programs directory seems to have vanished, probably about to fail to run a command in there\n";

    #see if the command exists
    my $command = get_command($all_commands, $lcasecmd);
    if (!defined $command) {
      $irc->yield( privmsg => $channel
                   => "Sorry $nick, I don't have a $lcasecmd command." );
      return;
    } elsif (ref $command) {
      $irc->yield( privmsg => $channel
                   => "Sorry $nick, I don't have a $lcasecmd command, ".
                      "or that wasn't unique, try one of @$command." );
      return;
    }

    my $script = $all_commands->{$command};

    # the scripts need their working directory to be the programsdir
    # we probably don't ever need another working directory
    chdir $programsdir; 

    # now we run the command, caprure() will NOT invoke a shell if it is called with
    # more than one argument. We need to eval this, or we will exit if the command
    # returns non zero status.
    eval {
      @output = capture($script, $nick, $channel, $channel, $argline, $lcasecmd);
    };
    if ($@) {
      $irc->yield( privmsg => $channel => "Sorry $nick, $lcasecmd is on fire." );
    }
  }
  for my $line (@output) {
    $irc->yield( privmsg => $channel => $line );
  }

  #This runs the "log" commands, we do not log these, care must be taken to make them lean, unspammy and few.
  #Update the list of log commands
  &get_commands_by_dir("$programsdir/log", \$log_commands_time, $log_commands);

  #the scripts expect their working directory to be the log commands directory
  chdir "$programsdir/log";

  #run each log command
  while ( my ($log_command, $log_command_path) = each(%$log_commands) ) {
    #run the log command
    eval {
      @output = capture($log_command_path, $nick, $channel, $channel, $what, $log_command, 'log');
    };
    if ($@) {
      #The STDERR of failing commands is already directed to the console, just abort this command
      next;
    }

    #say what needs to be seaid
    for my $line (@output) {
      $irc->yield( privmsg => $channel => $line);
    }
    
  }

  return;
}

sub get_command {
  my ($commands, $command) = @_;

  # first try exact command
  if (exists $commands->{$command}) {
    return $command;
  }
  my @res;
  # find any and all matching given prefix
  foreach my $key (keys %$all_commands) {
    if ($command eq substr $key, 0, length $command) {
      push @res, $key;
    }
  }
  # if there is only one then use that
  if (@res == 1) {
    return $res[0];
  }
  # if there are none, return undefined
  return unless (@res);
  # if there are several, return the list reference
  return \@res;
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

    my $lcasecmd = $1;
    $lcasecmd =~ tr/A-Z/a-z/;
    my $argline = $2;

    #update the list of programs
    &get_commands_by_dir($programsdir, \$all_commands_time, $all_commands) or print STDERR "Programs directory seems to have vanished, probably about to fail to run a command in there\n";

    #see if the command exists
    if (!$all_commands->{$lcasecmd}) {
      $irc->yield( privmsg => $nick  => "Sorry, I don't have a $lcasecmd command." );
      return;
    }

    # the scripts need their working directory to be the programsdir
    # we probably don't ever need another working directory
    chdir $programsdir; 

    # now we run the command, caprure() will NOT invoke a shell if it is called with
    # more than one argument. We need to eval this, or we will exit if the command
    # returns non zero status.
    eval {
      @output = capture($all_commands->{$lcasecmd}, $nick, 'null', $nick, $argline, $lcasecmd);
    };
    if ($@) {
      $irc->yield( privmsg => $nick => "Sorry, $lcasecmd is on fire." );
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

sub lag_o_meter {
  my ($kernel,$heap) = @_[KERNEL,HEAP];
  print 'Lag: ' . $heap->{connector}->lag() . "\n";
  $kernel->delay( 'lag_o_meter' => 60 );
  return;
}

sub listen_port_handler {
  my $line = $_[ARG0];
  $irc->yield( privmsg => $channels[0] => $line );
}
