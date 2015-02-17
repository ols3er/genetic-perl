use strict;
package Genetic;

my $arg_count = 3;
my @args = ();

for (1..$arg_count) {
    push @args, int(rand(100) + 2);
}


# fitness bonus if program parses correctly
my $program_valid = 10;

# bonus for right answer
my $right_answer = 100;

# bonus if result of program is not zero
my $nonzero_bonus = 20;

$Genetic::target = Genetic->get_arg(0) * Genetic->get_arg(1) - Genetic->get_arg(2)
    * Genetic->get_arg(0);

# fitness function
sub evaluate_fitness {
    my $creature = shift;

    my @program = @{$creature->program};
    my $fitness = 0;

    my $warncount = 0;
    local $SIG{__WARN__} = sub {$warncount++};
    my $result = run_program($creature);

    my $warning_bonus = 3 - ($warncount > 3 ? 3 : $warncount);
    $fitness += $warning_bonus;
    $creature->{warning_bonus} = $warning_bonus;

    # bonus for program parsing and evaluating
    if ($result) {
    $fitness += $program_valid;
    
    if (0) {
        # bonus for right answer
        if ($result == $target) {
            $fitness += $right_answer;

            print "\n\nargs: " . join(" ", Genetic->args) . "\n\n";
            print "Found answer: " . translate_program($creature) . "\ntarget: $target\n" .
                "program result: " . $result . "\n";

            unlink "population" if -e 'population';
            exit;
        }
    }

    # bonus for program length
#   $fitness += $max_prog_size - (scalar @program);
    }

    return $fitness;
}

sub args {
  my $class = shift;

  return @args;
}

sub get_arg {
    my ($class, $index) = @_;

    return $args[$index];
}

sub set_args {
    my ($class, @newargs) = @_;

    @args = @newargs;
}

sub serialize_population {
    my ($class, $population) = @_;

    my @serialized_population = ();

    foreach my $creature (@$population) {
        push @serialized_population, $creature->serialize;
    }

    return \@serialized_population;
}

sub deserialize_population {
    my ($class, $population) = @_;

    my @pop = ();

    foreach my $creature_data (@$population) {
        push @pop, Creature->deserialize($creature_data);
    }

    return @pop;
}

1;
