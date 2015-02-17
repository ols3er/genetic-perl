#!/bin/perl

use strict;
use Storable qw(nstore retrieve);
use POSIX;

use Genetic;
use Creature;
use Operation;
use Operations;

my $max_prog_size = 20;
my $min_prog_size = 3;

my $max_fitness = 0;
my $min_fitness = 1_000;
my $total_fitness;

my $identifier_count = 0;
my $generation_count = 1;
my $target;

# how many generations to do?
my $generations = $ARGV[1] || 100;

# how many creatures?
my $population_size = $ARGV[2] || 100;

# what is the probability a crossover will occur?
my $crossover_probability = 0.008;

# what is the probability a mutation will occur of a given opcode?
my $mutate_probability = $ARGV[0] || 0.003;

my $progress = 1;
my $debug = 0;

my @population = ();

my $save_data;
if (-e "population" && ($save_data = retrieve("population"))) {
    @population = Genetic->deserialize_population($save_data->{population});
    Genetic->set_args(@{$save_data->{args}});
} else {
    seed_population();
}

# fitness bonuses

# distance have to be from target to get bonus
my $target_distance_width = 100;

# fitness bonus if program parses correctly
my $program_valid = 10;

# bonus for right answer
my $right_answer = 100;

# bonus if result of program is not zero
my $nonzero_bonus = 20;


for (1..$generations) {
    $total_fitness = 0;
    $max_fitness = 0;
    $min_fitness = 1000;

    evaluate_population();
    print_results();
    perform_selection();
}
$total_fitness = 0;
$max_fitness = 0;
$min_fitness = 1000;
evaluate_population();
print_results();

print "\n\nArguments: ";
foreach my $arg (Genetic->args) {
    print "$arg ";
}
print "\n\n";

my $to_save = {
    population => Genetic->serialize_population(\@population),
    args => [Genetic->args],
};

nstore $to_save, "population"; 

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
        
        # bonus for close from target
        my $target_distance = POSIX::abs($target - int($result));

        my $target_distance_bonus = 0;

        if ($target_distance) {
            $target_distance_bonus = int(((POSIX::abs($target) * 2)/$target_distance))
            if $target_distance;
            $target_distance_bonus = $target_distance_width - $target_distance_width / $target_distance_bonus if $target_distance_bonus;
        }

        $creature->{target_distance_bonus} = $target_distance_bonus;
        $fitness += int($target_distance_bonus);

        #print "result $result distance: $target_distance target: $target bonus: $target_distance_bonus\n" if $target_distance_bonus > 1;

        # bonus for non-zero answer
        $fitness += $nonzero_bonus if (int($result) != 0);

        # bonus for right answer
        if ($result == $target) {
            $fitness += $right_answer;

            print "\n\nargs: " . join(" ", Genetic->args) . "\n\n";
            print "Found answer: " . translate_program($creature) . "\ntarget: $target\n" .
            "program result: " . $result . "\n";

            unlink "population" if -e 'population';
            exit;
        }

        # bonus for program length
        $fitness += $max_prog_size - (scalar @program);
    }

    return $fitness;
}

sub perform_selection {
    my @new_population = ();

    print "\n\t -- Generation $generation_count/$generations --\n\n";
    $generation_count++;

    # go through the population two at a time
    for (my $i=0; $i < scalar @population; $i+=2) {
        # just make extra-sure we still have creatures at this index
        my $creature = $population[$i];
        last unless $creature;

        if (scalar @population > 1000 && $i % 1000 == 0) {
            print "Selecting... $i/" . scalar @population . "\n" if $progress;
        }

        # pick two parents and recombine genes
        my $parent_1 = select_parent();
        my $parent_2 = select_parent();

        # reproduce, have two childre
        my @children = perform_reproduction($parent_1, $parent_2);

        if ($debug) {
            print "Parents: \n";
            print_creature($parent_1);
            print_creature($parent_2);
            print "\n\nChildren: \n";
            print_creature($children[0]);
            print_creature($children[1]);
        }

        # save the two children for the next generation
        push @new_population, @children;
    }

    # use the new generation
    @population = @new_population;

    print "\n";
}

# combine the genes of two parents and reproduce to create two children
# returns array of children creatures
sub perform_reproduction {
    my ($p1, $p2) = @_;

    my @p1_prog = @{$p1->{program}};
    my @p2_prog = @{$p2->{program}};

    my $c1 = Creature->new;
    my $c2 = Creature->new;

    my @c1_prog = ();
    my @c2_prog = ();

    my $i = 0;

    # are we going to do a crossover?
    if (rand() < $crossover_probability) {
        # find the index of the program where we're going to crossover
        my $cross_point = int(rand(max(scalar @p1_prog - 2, scalar @p2_prog - 2)));
        
        # do crossover (head-swap)
        for ($i = 0; $i < $cross_point; $i++) {
            push @c2_prog, mutate($p1_prog[$i]) if ($i < scalar @p1_prog);
            push @c1_prog, mutate($p2_prog[$i]) if ($i < scalar @p2_prog);
        }
    }

    my $max_parent_prog_size = max(scalar @p1_prog, scalar @p2_prog);
    my $new_prog_size = max($min_prog_size, int(rand($max_prog_size)));

    # mutate and pass genes on
    my $c1_opcode;
    my $c2_opcode;
    for ( ; $i < max($max_parent_prog_size, $new_prog_size) ; $i++) {
        $c1_opcode = ($i < scalar @p1_prog) ? mutate($p1_prog[$i], $c1_opcode) :
            get_opcode($c1_opcode);
        $c2_opcode = ($i < scalar @p2_prog) ? mutate($p2_prog[$i], $c1_opcode) :
            get_opcode($c2_opcode);

        push @c1_prog, $c1_opcode;
        push @c2_prog, $c2_opcode;
    }

    $c1->{program} = \@c1_prog;
    $c2->{program} = \@c2_prog;

    return ($c1, $c2);
}

# possibly mutate this opcode
sub mutate {
    my ($opcode, $lhs) = @_;

    return get_opcode($lhs) if (rand() < $mutate_probability);
    return $opcode;
}
    
my $creature_index = 0;

# choose a creature with a good fitness
sub select_parent {
    my $ret_fitness = 0;
    my $fit_marker = ((rand() * $total_fitness) * 0.25);
    
    my $ret = -1;

    # loop around the population until we find a fit candidate
    do {
        my $creature_fitness = ${population[$creature_index]}->fitness;
        $ret_fitness += $creature_fitness;

    #   printf "total: $total_fitness marker: $fit_marker   fitness: %3.0f... \t", $creature_fitness;
        if ($ret_fitness >= $fit_marker) {
            $ret = $creature_index;
    #       print "ACCEPT\n";
        } else {
    #       print "reject\n";
        }

        $creature_index = 0 if (++$creature_index == scalar @population);
    } while ($ret == -1);

    return $population[$ret];
}

# calculate fitness of every creature
sub evaluate_population {
    my $count = 0;

    foreach my $creature (@population) {
        if (scalar @population > 1000 && $count % 1000 == 0) {
            print "Evaluating population... $count/ " . scalar @population . "\n" if $progress;
        }
        $count++;

        $creature->{fitness} = evaluate_fitness($creature);
        
        $total_fitness += $creature->{fitness};
    }

    print "\n";
}

sub run_program {
    my $creature = shift;

    my @arguments = Genetic->args;

    return eval(translate_program($creature));
}

sub translate_program {
    my $creature = shift;
    my $program = $creature->program;

    my $code = '';
    $identifier_count = 0;

    foreach my $operation (@$program) {
        $code .= $operation->as_string . ' ';
    }

    return $code;
}

sub print_results {
    my $fittest_creature;
    my $average_fitness = 0;

    foreach my $creature (@population) {
        my $fitness = $creature->fitness;
        $average_fitness += $fitness;

        if ($fitness > $max_fitness) {
            $max_fitness = $fitness;
            $fittest_creature = $creature;
        }

        $min_fitness = $fitness if ($fitness < $min_fitness);
    }

    $average_fitness = int($average_fitness / scalar @population);

    print "max_fitness:\t\t$max_fitness\n" .
      "min_fitness:\t\t$min_fitness\n" .
      "total_fitness:\t\t$total_fitness\n" .
      "average_fitness:\t$average_fitness\n";
      #"population size: " . scalar @population . "\n";

    if ($fittest_creature) {
        print "Best program: ";
        print_program($fittest_creature);
        print "Program result: " . int(run_program($fittest_creature)) . "\n";
        print "Program fitness: " . $fittest_creature->{fitness} . "\n";
        print "Target distance bonus: " . $fittest_creature->{target_distance_bonus} . "\n"
            if $fittest_creature->{target_distance_bonus};
        print "Warning bonus: " . $fittest_creature->{warning_bonus} . "\n"
            if $fittest_creature->{warning_bonus};
        print "Target: $target\n";
    }
}

sub print_program {
    my $creature = shift;
    return undef unless $creature;

    my $code = translate_program($creature);
    print "$code\n";
}

sub print_creature {
    my $creature = shift;
    return undef unless $creature;

    my @program = @{$creature->program};

    print "\nFitness: $creature->{fitness}\nProgram: ";
    foreach my $opcode (@program) {
        print "$opcode ";
    }
    print "\n";
}

sub seed_population {
    my $count = 0;

    for (1..$population_size) {
        if ($count % 10 == 0) {
            print "Seeding popuation... $count/$population_size\n" if $progress; 
        }
        $count++;

        my $creature = Creature->new;

        my $ok = 0;
        do {
            my $last_opcode;
            my @program = ();

            my $opcode_count = 0;
            for(0..max($min_prog_size, int(rand($max_prog_size)))) {
            $last_opcode = Operation->next_valid_opcode($last_opcode);
            push @program, $last_opcode;
            }

            $creature->set_program(\@program);

            my $warncount = 0;
            local $SIG{__WARN__} = sub {$warncount++};
            $ok = run_program($creature);
        } until ($ok);

        push @population, $creature;
    }

    print "\n";
}

# return a random operation
sub get_opcode {
    my $lhs = shift;

    return Operation->next_valid_opcode($lhs);
}

sub create_identifier {
    return 'my $i' . $identifier_count++ . '=0; ';
}

sub get_identifier {
    my $ret = '';

    $ret .= create_identifier() unless $identifier_count;

    return $ret . '$i' . int(rand($identifier_count));
}

sub return_identifier {
    return 'return ' . get_identifier() . ';';
}

sub get_argument {
    return '$arguments[' . int(rand(scalar Genetic->args)) . '] ';
}

sub get_number {
    return int(rand(10));
}

sub max {
    my ($a, $b) = @_;
    return $b > $a ? $b : $a;
}
