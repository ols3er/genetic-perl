use strict;
use Carp;
package Operation;

sub new {
  my ($class, %opts) = @_;

  my $randseed = delete $opts{randseed} || rand() * 1000000000000000;

  Carp::croak "Invalid arguments passed to Operation::new" if keys %opts;

  my $self = {
      randseed => $randseed,
  };

  bless $self, $class;

  return $self;
}

sub as_string {
    my $self = shift;

    my $opcode = $self->opcode;

    return $opcode;
}

sub copy {
    my $self = shift;
    my $package_name = ref($self);

    return $package_name->new;
}

sub is_valid {
    my ($self, $lhs) = @_;

    return $self->validator((ref $lhs));
}

# returns an operation
# if called on an instance returns a valid operation to follow this instance
# if class method call then returns a valid starting operation
sub next_valid_opcode {
    my ($self, $lhs) = @_;

    $self = $lhs unless ref $self;

    my $valid = 0;
    my $opcopy;

    # try getting random opcodes until a valid one
    until ($valid) {
        my $operation = $Operations::OperationList[int(rand(scalar @Operations::OperationList))];

        $opcopy = $operation->copy;

        $valid = $opcopy->is_valid($self);
    }

    return $opcopy;
}

# overload this!
sub validator {
    return 1;
}

sub serialize {
    my ($self) = @_;

    return {
        randseed => $self->{randseed},
        opcode_class => (ref $self),
    };
}

# class method takes serialized data structure
sub deserialize {
    my ($class, $data) = @_;

    my $opcode_class = $data->{opcode_class};

    my $self = $opcode_class->new(
        randseed => $data->{randseed},
    );

    return $self;
}

1;
        
