use strict;
use Operation;

package Operation::BinaryOperation;
use base 'Operation';

sub validator {
    my ($self, $lhs) = @_;

    return ($lhs =~ /LiteralOperation/i);
}

package Operation::StatementOperation;
use base 'Operation';

sub validator {
    my ($self, $lhs) = @_;

    # ok after literal or unary
    return ($lhs =~ /(UnaryOperation|LiteralOperation)/i);
}

package Operation::LiteralOperation;
use base 'Operation';

sub validator {
    my ($self, $lhs) = @_;

    return 1 unless $lhs;
    return ($lhs =~ /(BinaryOperation|UnaryOperation|StatementOperation)/i);
}

#############################
package Operation::BinaryOperation::Add;
use base 'Operation::BinaryOperation';
sub opcode { return '+'; }

package Operation::BinaryOperation::Subtract;
use base 'Operation::BinaryOperation';
sub opcode { return '-'; }

package Operation::BinaryOperation::Multiply;
use base 'Operation::BinaryOperation';
sub opcode { return '*'; }

package Operation::BinaryOperation::Divide;
use base 'Operation::BinaryOperation';
sub opcode { return '/'; }

package Operation::LiteralOperation::Argument;
use base 'Operation::LiteralOperation';
sub opcode {
    my $self = shift;
    return '$arguments[' . ($self->{randseed} % (scalar Genetic->args)) . ']';
}

package Operation::LiteralOperation::Integer;
use base 'Operation::LiteralOperation';
sub opcode { my $self = shift; return $self->{randseed} % 10 + 1; }

package Operation::StatementOperation::Statement;
use base 'Operation::StatementOperation';
sub opcode { return ';'; }

package Operations;

my $add = Operation::BinaryOperation::Add->new;
my $multiply = Operation::BinaryOperation::Multiply->new;
my $subtract = Operation::BinaryOperation::Subtract->new;
my $divide = Operation::BinaryOperation::Divide->new;
my $argument = Operation::LiteralOperation::Argument->new;
my $statement = Operation::StatementOperation::Statement->new;
my $integer = Operation::LiteralOperation::Integer->new;

@Operations::OperationList = (
    $add,
    $multiply,
    $subtract,
    $divide,
    $argument,
    $integer,
    $statement,
);

# class method returns a statement operation
sub statement {
    my $class = shift;

    return $statement->copy;
}

1;
