use strict;
package Creature;

sub new {
  my ($class) = @_;

  my $self = {
	      fitness => 0,
	      program => [],
	      randseed => rand()*1000000000000000,
	     };
  bless $self, $class;

  return $self;
}

sub program {
  my $self = shift;

  return $self->{program};
}

sub set_program {
  my ($self, $program) = @_;

  $self->{program} = $program || [];
}

sub randseed {
  my $self = shift;

  return $self->{randseed};
}

sub fitness {
  my $self = shift;

  return $self->{fitness};
}

sub serialize {
  my $self = shift;

  my $program = $self->program;
  
  my $to_store = {
      fitness => $self->fitness,
      randseed => $self->randseed,
  };

  my @operations = ();
  foreach my $operation (@$program) {
      push @operations, $operation->serialize;
  }

  $to_store->{program} = \@operations;

  return $to_store;
}

# class method, takes serialized data structure
sub deserialize {
    my ($class, $data) = @_;

    my $self = $class->new;
    $self->{fitness} = $data->{fitness};
    $self->{randseed} = $data->{randseed};

    my $operations = $data->{program};

    foreach my $operation_data (@$operations) {
	push @{$self->{program}}, Operation->deserialize($operation_data);
    }

    return $self;
}

1;
