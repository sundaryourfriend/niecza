# vim: ft=perl6
use Test;
use MONKEY_TYPING;

{
    # GH-3
    my class A { method Numeric { 42 } }
    is A.new + 23, 65, '+ calls user-written .Numeric';
}

{
    "abc" ~~ /. (.) ./;
    is $0, 'b', 'Regex matches set $/';
}

{
    "abc" ~~ /de(.)/;
    ok !defined($/), 'Failed regex matches clear $/';
}

{
    my @foo = 1, 2, 3, 4, 5;

    is @foo[2,3].join('|'), '3|4', 'slicing works';
    is @foo[{ $^x / 2 }], 3, 'code indexes work';
    is @foo[*-1], 5, 'WhateverCode indexes work';
    is @foo[[1,4]].join('|'), 3, 'items do not slice';
}

#is $?FILE, 'test.pl', '$?FILE works';
#is $?ORIG.substr(0,5), '# vim', '$?ORIG works';

# {
#     {
#         our $x = 5; #OK
#     }
#     ok $::x == 5, '$::x finds our variable';
# 
#     package Fao { our $y = 6; } #OK
#     ok $::Fao::y == 6, '$::Fao::y works as $Fao::y';
# 
#     { class Mao { } }
#     ok ::Mao.new.defined, 'can use classes via ::Mao';
# }
# 
# {
#     my $x = 7; #OK
#     ok $::x == 7, '$::x can find lexicals';
#     class A3 {
#         method moo { 42 }
#         class B4 {
#             ok ::A3.moo, '::A3 can find outer classes';
#         }
#     }
# }

done-testing;
