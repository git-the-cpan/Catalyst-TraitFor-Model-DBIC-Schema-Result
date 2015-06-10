package Catalyst::TraitFor::Model::DBIC::Schema::Result;

use Moose::Role;

our $VERSION = '0.003';

after '_install_rs_models', sub {
  my $self  = shift;
  my $class = $self->_original_class_name;
 
  no strict 'refs';
  my @sources = $self->schema->sources;
  die "No sources for your schema" unless @sources;

  foreach my $moniker (@sources) {
    my $classname = "${class}::${moniker}::Result";
    *{"${classname}::ACCEPT_CONTEXT"} = sub {
      my ($result_self, $c, @passed_args) = @_;
      my $id = '__' . ref($result_self);

      # Allow one to 'reset' the current IF there's @passed_args.

      delete $c->stash->{$id} if exists($c->stash->{$id}) && scalar(@passed_args);

      return $c->stash->{$id} ||= do {
        my @args = @{$c->request->args};
        my @arg = @{$c->request->args}; # common typo.
        if(my $template = $c->action->attributes->{ResultModelFrom}) {
          @args = (eval " {$template->[0]}");
        }

        ## Arguments passed via ->Model take precident.
        my @find = scalar(@passed_args) ? @passed_args : @args;

        $c->model($self->model_name)
        ->resultset($moniker)
          ->find(@find); # this line is pretty much the whole point
      };
    };
  }
};

1;

=head1 NAME

Catalyst::TraitFor::Model::DBIC::Schema::Result - PerRequest Result from Catalyst Request

=head1 SYNOPSIS

In your configuration, set the trait:

    MyApp->config(
      'Model::Schema' => {
        traits => ['Result'],
        schema_class => 'MyApp::Schema',
        connect_info => [ ... ],
      },
    );

Now in your actions you can call the generated models, which get their ->find($id) from
$c->request->args.

    sub user :Local Args(1) {
      my ($self, $c) = @_;
      my $user = $c->model('Schema::User::Result');
    }

You can also control how the 'find' on the Resultset works via an action attribute
('ResultModelFrom') or via arguments passed to the 'model' call.

=head1 DESCRIPTION

Its a common case to get the result of a L<DBIx::Class> '->find' based on the current
L<Catalyst> request (typically from the Args attribute).  This is an experimental trait
to see if we can usefully encapsulate that common task in a way that is not easily broken.

If you can't read the source code and figure out what is going on, might want to stay
away for now!

When you compose this trait into your MyApp::Model::Schema (subclass of
L<Catalyst::Model::DBIC::Schema>) it automatically creates a second PerRequest model
for each ResultSource in your Schema.  This new Model is named by taking the name
of the resultsource (for example 'Schema::User') and adding '::Result' to it (or
in the example case 'Schema::User::Result').  When you request an instance of this
model, it will automatically assume the first argument of the current action is intended
to be the index by which the ->find locates your database row.  So basically the two
following actions are the same in effect:

With trait:

    sub user :Local Args(1) {
      my ($self, $c) = @_;
      my $user = $c->model('Schema::User::Result');
    }

Without trait:

    sub user :Local Args(1) {
      my ($self, $c, $id) = @_;
      my $user = $c->model('Schema::User')->find($id);
    }

I recommend that if you can use L<Catalyst> 5.9009x+ that you use a type constraint
to make sure the argument is the correct type (otherwise you risk generating a
database error if the user tries to submit a string arg and the database is expecting
an integer:

    use Types::Standard 'Int';

    sub user :Local Args(Int) {
      my ($self, $c) = @_;
      my $user = $c->model('Schema::User::Result');
    }

=head1 SUBROUTINE ATTRIBUTES

For the case when a result is complex (requires more than one argument) or you 
want to use a key other then the PK, you may add a subroutine argument to describe
the pattern:

  sub user_with_attr :Local Args(1) ResultModelFrom(first_name=>$args[0]) {
    my ($self, $c) = @_;
  }

This is experimental and may change as needed.  Basically this get converted
to a hashref and submitted to ->find.

=head1 Passing arguments to ->model

Lastly, you may passing arguments to find via the ->model call.  The following
are examples

With trait:

    sub user :Local Args(1) {
      my ($self, $c) = @_;
      my $user = $c->model('Schema::User::Result', $some_other_id);
    }

Without trait:

    sub user :Local Args(1) {
      my ($self, $c, $id) = @_;
      my $user = $c->model('Schema::User')->find($some_other_id);
    }

With trait:

    sub user :Local Args(1) {
      my ($self, $c) = @_;
      my $user = $c->model('Schema::User::Result', +{first_name=>'john'});
    }

Without trait:

    sub user :Local Args(1) {
      my ($self, $c, $id) = @_;
      my $user = $c->model('Schema::User')->find({first_name=>'john'});
    }

If you choose to pass arguments this way, each call will 'reset' the current
model (changing PerRequest into a Factory type).  This behavior is still
subject to change).

=head1 SEE ALSO

L<Catalyst>, L<Catalyst::Model::DBIC::Schema>.

=head1 AUTHOR
 
John Napiorkowski L<email:jjnapiork@cpan.org>
  
=head1 COPYRIGHT & LICENSE
 
Copyright 2015, John Napiorkowski L<email:jjnapiork@cpan.org>
 
This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut