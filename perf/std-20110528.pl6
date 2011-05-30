use JSYNC;

sub calibrate() {
    my $start = now.to-posix.[0];
    my $i = -1000000;
    my $f = sub () {};
    $f() while $i++;
    my $end = now.to-posix.[0];
    ($end - $start) / 1000000;
}

my $base = calibrate();

sub bench($name, $nr, $f) {
    my $start = now.to-posix.[0];
    my $i = -$nr;
    $f() while $i++;
    my $end   = now.to-posix.[0];
    say "$name = {($end - $start) / $nr - $base} [raw {$end-$start} for $nr]";
}

bench "nulling test", 1000000, sub () {};
# {
#    my @l;
#    bench "iterate empty list", 1000000, sub () { for @l { } };
# }

my @x; my $y; my $z; my %h;
bench "scalar assign", 1000000, sub () { $y = 1; $y = 2; $y = 3; $y = 4; $y = 5; $y = 6; $y = 7; $y = 8; $y = 9; $y = 10 };
bench "list assign (Parcel)", 1000000, sub () { ($y,$z) = ($z,$y) };
bench "list assign (Array)", 1000000, sub () { @x = 1, 2, 3 };
bench "list assign (Hash)", 1000000, sub () { %h = "a", 1, "b", 2 };
bench 'head assign (&head)', 1000000, sub () { $y = head((1,2,3)) };
bench 'head assign (Parcel)', 1000000, sub () { ($y,) = (1,2,3) };

# my %h; my $x;
# bench "Hash.delete-key", 1000000, sub () { %h<foo>:delete };
# bench "Any.delete-key", 1000000, sub () { $x<foo>:delete };
# bench "Bool.Numeric", 1000000, sub () { +True };

# my ($x, $y);
# bench "Parcel.LISTSTORE", 1000000, sub () { ($x,$y) = ($y,$x) };
# {
#     "foo" ~~ /f(.)/;
#     bench '$<x>', 1000000, sub () { $0 };
# }
# 
# my $str = "0";
# $str ~= $str for ^18;
# say $str.chars;
# # $str = substr($str,0,1000000);
# 
# my grammar GTest {
#     token TOP { <.bit>* }
#     token bit { . }
# }
# 
# bench "grammar", 1, sub () { GTest.parse($str) };
# {
#     my class GAct0 {
#     }
#     bench "grammar (no action)", 1, sub () { GTest.parse($str, :actions(GAct0)) };
# }
# 
# {
#     my class GAct1 {
#         method bit($ ) { }
#     }
#     bench "grammar (empty action)", 1, sub () { GTest.parse($str, :actions(GAct1)) };
# }
# 
# {
#     my class GAct2 {
#         method FALLBACK($ , $ ) { }
#     }
#     bench "grammar (fallback action)", 1, sub () { GTest.parse($str, :actions(GAct2)) };
# }
# 
# bench "Any.exists-key", 1000000, sub () { Any<foo>:exists };
# 
# my $arr = [1];
# bench "JSON array iteration", 1000000, sub () { to-json($arr) };