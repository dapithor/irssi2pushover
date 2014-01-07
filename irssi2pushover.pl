use strict;
use warnings;

use LWP::UserAgent;
use HTTP::Request::Common;
use Irssi;
use vars qw($VERSION %IRSSI);

$VERSION = "0.1";
%IRSSI = (
  authors     => "dap",
  contact     => "@dapithor",
  name        => "pushover",
  description => "Sends PUSH notifcations to Pushover",
  license     => "",
  url         => "https://github.com/dapithor/irssi2pushover",
  changed     => "Tue Jan 07 11:11:11 EDT 2014",
);

sub debug {
  return unless Irssi::settings_get_bool('pushover_debug');
  my $text = shift;
  my @caller = caller(1);
  Irssi::print('From '.$caller[3].': '.$text);
}

sub pushmsgs {
  my ($type, $message, $target) = @_;
  # drop message if empty line
  #return if ($message =~ m/^\s*$/);

  # Pushover API URL
  my $pushover_uri = 'https://api.pushover.net/1/messages.json';
  # Setup constructor to connect
  #my $pushover_agent = LWP::UserAgent->new;
  my $pushover = LWP::UserAgent->new;
  $pushover->agent("irssi-pushover/$VERSION");

  my %msg_opts = (
    'token' => Irssi::settings_get_str('pushover_apptoken'),
    'user' => Irssi::settings_get_str('pushover_userkey'),
    'title' => &create_title($type, $target),
    'message' => $message,
  );
  if (!$msg_opts{'token'}) { debug('Missing pushover app token.'); return; }

  debug('pushmsgs: Sending notification.');
  my $pushmsg = $pushover->post( $pushover_uri, 'Content-Type' => 'application/x-www-form-urlencoded', Content => \%msg_opts);
  if ($pushmsg->is_success) {
    Irssi::print("Pushed: " . $message);
    debug('Notification sent: ' . $pushmsg->decoded_content);
  } else {
    Irssi::print("Push Error received from Pushover.");
    debug('Push ERROR: ' . $pushmsg->status_line);
  }
}

# create a title for the pushover message
sub create_title {
  my ($type, $target) = @_;
  if ($type eq 'private') {
    return "irssi: priv msg from $target";
  } elsif ($type eq 'public') {
    return "irssi: mentioned in $target";
  } elsif ($type eq 'hilightcatcher') {
    return "irssi: hilight $target";
  }
  else {
    die "Received unknown message type \"$type\" in create_title\n";
  }
}

# handles the processing of messages
sub event_handler {
  my ($server, $msg, $nick, $address, $target) = @_;
  #foreach(@_) { Irssi::print("Debug event_handler arg: ". $_); }
  return unless (Irssi::settings_get_bool('pushover_enable'));
  if ($target) {
    if (!Irssi::settings_get_bool('pushover_hilight_catcher_enable')) {
      # Send public message since $target is a channel AND hilight_catcher is disabled
      pushmsgs('public', "<$nick> $msg", $target) if ($msg =~ m/$server->{'nick'}/);
    }
  } else {
    # private message (this is NOT the correct way to do this.  Might catch other events)
    pushmsgs('private', $msg, $nick) if (Irssi::settings_get_bool('pushover_notify_on_privmsg'));
    #pushmsgs('private', $nick, $msg);
  }
}
sub hilight_catcher {
  my($dest, $text, $stripped) = @_;
  my $server = $dest->{server};

  if($dest->{level} & MSGLEVEL_HILIGHT) {
    pushmsgs('hilightcatcher', $stripped, 'catcher') if (Irssi::settings_get_bool('pushover_hilight_catcher_enable'));
  }
}

Irssi::settings_add_str($IRSSI{'name'}, 'pushover_apptoken', '');
Irssi::settings_add_str($IRSSI{'name'}, 'pushover_userkey', '');
Irssi::settings_add_bool($IRSSI{'name'}, 'pushover_debug', 1);
Irssi::settings_add_bool($IRSSI{'name'}, 'pushover_enable', 1);

#extras:
Irssi::settings_add_bool($IRSSI{'name'}, 'pushover_notify_on_privmsg', 1);

# signal handlers
Irssi::signal_add_last("message public", "event_handler");
Irssi::signal_add_last("message private", "event_handler");
Irssi::signal_add_last('print text', 'hilight_catcher');
# hilight catcher extras:
# enable notifications on irssi specified /hilight(s)
Irssi::settings_add_bool($IRSSI{'name'}, 'pushover_hilight_catcher_enable', 0);

# onload print version and tell user to set options:
Irssi::print('%Y>>%n '.$IRSSI{name}.' '.$VERSION.' loaded.');
if (!Irssi::settings_get_str('pushover_userkey')) {
  Irssi::print('%Y>>%n '.$IRSSI{name}.' Pushover User Key is not set, set it with /set pushover_userkey KEY');
}
if (!Irssi::settings_get_str('pushover_apptoken')) {
  Irssi::print('%Y>>%n '.$IRSSI{name}.' Pushover application token is not set, set it with /set pushover_apptoken TOKEN');
}
if (Irssi::settings_get_bool('pushover_notify_on_privmsg')) {
  Irssi::print('%Y>>%n '.$IRSSI{name}.' Notify on PrivMsg is on, disable with /set pushover_notify_on_privmsg OFF');
}
if (Irssi::settings_get_bool('pushover_hilight_catcher_enable')) {
  Irssi::print('%Y>>%n '.$IRSSI{name}.' Notify on hilights is off, enable with /set pushover_hilight_catcher_enable OFF');
}
if (!Irssi::settings_get_bool('pushover_enable')) {
  Irssi::print('%Y>>%n '.$IRSSI{name}.' Pushover disabled, enable with /set pushover_enable ON');
}
